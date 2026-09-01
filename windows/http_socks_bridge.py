#!/usr/bin/env python3
"""
HTTP to SOCKS5 Bridge Proxy
Listens on 127.0.0.1:8080 and routes all HTTP/HTTPS traffic through SOCKS5 on 127.0.0.1:1080
Provides a safe barrier against IP and DNS leaks.
"""

import asyncio
import struct
import sys
import logging

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger("HTTP-SOCKS5-Bridge")

SOCKS_HOST = "127.0.0.1"
SOCKS_PORT = 1080
LISTEN_HOST = "127.0.0.1"
LISTEN_PORT = 8080

async def socks5_connect(target_host: str, target_port: int):
    try:
        reader, writer = await asyncio.open_connection(SOCKS_HOST, SOCKS_PORT)
    except Exception as e:
        logger.error(f"Failed to connect to SOCKS5 server ({SOCKS_HOST}:{SOCKS_PORT}): {e}")
        return None, None

    # Step 1: Greeting (Version 5, 1 Auth Method: No Auth 0x00)
    writer.write(b"\x05\x01\x00")
    await writer.drain()

    try:
        resp = await reader.readexactly(2)
    except Exception:
        writer.close()
        await writer.wait_closed()
        return None, None

    if resp[0] != 5 or resp[1] != 0:
        logger.error(f"SOCKS5 auth negotiation failed: {resp}")
        writer.close()
        await writer.wait_closed()
        return None, None

    # Step 2: Request CONNECT by domain name (0x03)
    host_bytes = target_host.encode("idna")
    port_bytes = struct.pack("!H", target_port)
    req = b"\x05\x01\x00\x03" + bytes([len(host_bytes)]) + host_bytes + port_bytes
    writer.write(req)
    await writer.drain()

    # Step 3: Response
    try:
        resp_header = await reader.readexactly(4)
    except Exception:
        writer.close()
        await writer.wait_closed()
        return None, None

    if resp_header[0] != 5 or resp_header[1] != 0:
        logger.error(f"SOCKS5 connection rejected for {target_host}:{target_port} (code {resp_header[1]})")
        writer.close()
        await writer.wait_closed()
        return None, None

    # Read the rest of the bound address/port
    atyp = resp_header[3]
    if atyp == 1:  # IPv4
        await reader.readexactly(4 + 2)
    elif atyp == 3:  # Domain
        len_b = await reader.readexactly(1)
        await reader.readexactly(len_b[0] + 2)
    elif atyp == 4:  # IPv6
        await reader.readexactly(16 + 2)

    return reader, writer

async def pipe(reader, writer):
    try:
        while True:
            data = await reader.read(65536)
            if not data:
                break
            writer.write(data)
            await writer.drain()
    except (asyncio.CancelledError, ConnectionResetError, BrokenPipeError):
        pass
    except Exception as e:
        logger.debug(f"Pipe error: {e}")
    finally:
        try:
            writer.close()
            await writer.wait_closed()
        except Exception:
            pass

async def handle_client(client_reader, client_writer):
    try:
        header_data = await client_reader.readuntil(b"\r\n\r\n")
    except Exception:
        client_writer.close()
        await client_writer.wait_closed()
        return

    lines = header_data.split(b"\r\n")
    request_line = lines[0].decode("latin1", errors="replace")
    parts = request_line.split(" ")
    if len(parts) < 3:
        client_writer.close()
        await client_writer.wait_closed()
        return

    method, url, version = parts[0], parts[1], parts[2]

    if method.upper() == "CONNECT":
        if ":" in url:
            target_host, target_port_str = url.split(":", 1)
            try:
                target_port = int(target_port_str)
            except ValueError:
                target_port = 443
        else:
            target_host = url
            target_port = 443

        socks_reader, socks_writer = await socks5_connect(target_host, target_port)
        if not socks_reader or not socks_writer:
            client_writer.write(b"HTTP/1.1 502 Bad Gateway (SOCKS5 Tunnel Offline)\r\n\r\n")
            await client_writer.drain()
            client_writer.close()
            await client_writer.wait_closed()
            return

        client_writer.write(b"HTTP/1.1 200 Connection Established\r\n\r\n")
        await client_writer.drain()

        await asyncio.gather(
            pipe(client_reader, socks_writer),
            pipe(socks_reader, client_writer),
            return_exceptions=True
        )

    else:
        target_host = None
        target_port = 80

        for line in lines[1:]:
            decoded_line = line.decode("latin1", errors="replace")
            if decoded_line.lower().startswith("host:"):
                host_val = decoded_line.split(":", 1)[1].strip()
                if ":" in host_val:
                    h, p = host_val.split(":", 1)
                    target_host = h
                    try:
                        target_port = int(p)
                    except ValueError:
                        target_port = 80
                else:
                    target_host = host_val
                break

        if not target_host:
            if url.startswith("http://"):
                rest = url[7:]
                host_part = rest.split("/", 1)[0]
                if ":" in host_part:
                    h, p = host_part.split(":", 1)
                    target_host = h
                    try:
                        target_port = int(p)
                    except ValueError:
                        target_port = 80
                else:
                    target_host = host_part

        if not target_host:
            client_writer.write(b"HTTP/1.1 400 Bad Request\r\n\r\n")
            await client_writer.drain()
            client_writer.close()
            await client_writer.wait_closed()
            return

        socks_reader, socks_writer = await socks5_connect(target_host, target_port)
        if not socks_reader or not socks_writer:
            client_writer.write(b"HTTP/1.1 502 Bad Gateway (SOCKS5 Tunnel Offline)\r\n\r\n")
            await client_writer.drain()
            client_writer.close()
            await client_writer.wait_closed()
            return

        socks_writer.write(header_data)
        await socks_writer.drain()

        await asyncio.gather(
            pipe(client_reader, socks_writer),
            pipe(socks_reader, client_writer),
            return_exceptions=True
        )

async def main():
    server = await asyncio.start_server(handle_client, LISTEN_HOST, LISTEN_PORT)
    logger.info(f"HTTP/HTTPS Bridge active on {LISTEN_HOST}:{LISTEN_PORT} -> SOCKS5 on {SOCKS_HOST}:{SOCKS_PORT}")
    async with server:
        await server.serve_forever()

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        pass
