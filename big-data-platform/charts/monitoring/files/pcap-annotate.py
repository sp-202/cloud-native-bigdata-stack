#!/usr/bin/env python3
"""pcap -> pcapng with the pods on both ends of every packet in its comment.

    pcap-annotate.py IN.pcap OUT.pcapng PODMAP.jsonl [IPCACHE.json]

tcpdump's legacy .pcap has no place for metadata, so a capture shows IPs only and joining
them to pods meant reading pods-*.jsonl separately. This rewrites a finished capture as
pcapng with an opt_comment on each Enhanced Packet Block, e.g.

    src 10.0.4.17 default/tpch-sf1000-28x10-exec-3 -> dst 52.219.62.10 external

which Wireshark shows as frame.comment (filter: frame.comment contains "exec-3") and tshark
extracts with -e frame.comment. Packet bytes, timestamps and link type are unchanged.

PODMAP is the pod map capture.sh writes for this node (one JSON object per pod, the same
fields as pods-*.jsonl). IPCACHE remembers every IP -> pod seen before, so a packet from a
pod that has since exited still resolves. Host-network pods share the node IP and are
labelled as the node rather than guessed at.

Standard library only (Python 3.9: the amazon/aws-cli image). Reads linktypes LINUX_SLL2
(what `tcpdump -i any` writes), LINUX_SLL, EN10MB and RAW; anything else is copied through
with no comments. Exit status non-zero on a malformed input -- the caller then uploads the
original .pcap instead, so a converter bug can never lose a capture.
"""
import json
import os
import socket
import struct
import sys

LINKTYPE_ETHERNET = 1
LINKTYPE_RAW = 101
LINKTYPE_LINUX_SLL = 113
LINKTYPE_LINUX_SLL2 = 276


def load_names(podmap_path, cache_path):
    # node-local-dns listens on this link-local address on every node; without a name, every
    # DNS query on the node showed up as "external -> external".
    names = {"169.254.20.10": "kube-system/node-local-dns"}
    if cache_path and os.path.exists(cache_path):
        try:
            with open(cache_path) as f:
                names.update(json.load(f))
        except (OSError, ValueError):
            pass
    host_ips = set()
    try:
        with open(podmap_path) as f:
            for line in f:
                try:
                    p = json.loads(line)
                except ValueError:
                    continue
                ip = p.get("pod_ip")
                if not ip:
                    continue
                if p.get("host_network"):
                    host_ips.add(ip)
                    names[ip] = "node/" + (p.get("node") or "?")
                else:
                    names[ip] = "%s/%s" % (p.get("namespace") or "?", p.get("pod") or "?")
                if p.get("host_ip"):
                    host_ips.add(p["host_ip"])
                    names[p["host_ip"]] = "node/" + (p.get("node") or "?")
    except OSError:
        pass
    if cache_path:
        tmp = cache_path + ".tmp"
        try:
            with open(tmp, "w") as f:
                json.dump(names, f)
            os.replace(tmp, cache_path)
        except OSError:
            pass
    return names


def l3_offset(linktype, data):
    """(ethertype, offset of the IP header) or (None, None)."""
    if linktype == LINKTYPE_LINUX_SLL2 and len(data) >= 20:
        return struct.unpack(">H", data[0:2])[0], 20
    if linktype == LINKTYPE_LINUX_SLL and len(data) >= 16:
        return struct.unpack(">H", data[14:16])[0], 16
    if linktype == LINKTYPE_ETHERNET and len(data) >= 14:
        et, off = struct.unpack(">H", data[12:14])[0], 14
        while et in (0x8100, 0x88A8) and len(data) >= off + 4:   # VLAN tags
            et, off = struct.unpack(">H", data[off + 2:off + 4])[0], off + 4
        return et, off
    if linktype == LINKTYPE_RAW and data:
        v = data[0] >> 4
        return (0x0800 if v == 4 else 0x86DD if v == 6 else None), 0
    return None, None


def endpoints(linktype, data):
    et, off = l3_offset(linktype, data)
    if et == 0x0800 and len(data) >= off + 20:
        return socket.inet_ntoa(data[off + 12:off + 16]), socket.inet_ntoa(data[off + 16:off + 20])
    if et == 0x86DD and len(data) >= off + 40:
        return (socket.inet_ntop(socket.AF_INET6, data[off + 8:off + 24]),
                socket.inet_ntop(socket.AF_INET6, data[off + 24:off + 40]))
    return None, None


def pad4(b):
    return b + b"\0" * (-len(b) % 4)


def option(code, value):
    return struct.pack("<HH", code, len(value)) + pad4(value)


def block(btype, body):
    total = 12 + len(body)
    return struct.pack("<II", btype, total) + body + struct.pack("<I", total)


def main():
    if len(sys.argv) < 4:
        sys.exit("usage: pcap-annotate.py IN.pcap OUT.pcapng PODMAP.jsonl [IPCACHE.json]")
    src, dst, podmap = sys.argv[1], sys.argv[2], sys.argv[3]
    cache = sys.argv[4] if len(sys.argv) > 4 else None
    names = load_names(podmap, cache)

    with open(src, "rb") as f:
        hdr = f.read(24)
        if len(hdr) < 24:
            sys.exit("%s: truncated pcap header" % src)
        magic = hdr[:4]
        if magic in (b"\xd4\xc3\xb2\xa1", b"\x4d\x3c\xb2\xa1"):
            e = "<"
        elif magic in (b"\xa1\xb2\xc3\xd4", b"\xa1\xb2\x3c\x4d"):
            e = ">"
        else:
            sys.exit("%s: not a pcap file" % src)
        nanos = magic in (b"\x4d\x3c\xb2\xa1", b"\xa1\xb2\x3c\x4d")
        snaplen, linktype = struct.unpack(e + "II", hdr[16:24])
        linktype &= 0x0FFFFFFF        # high bits may carry FCS info

        tmp = dst + ".tmp"
        n = 0
        with open(tmp, "wb") as out:
            # Section Header Block: byte-order magic, v1.0, section length unknown (-1).
            out.write(block(0x0A0D0D0A,
                            struct.pack("<IHHq", 0x1A2B3C4D, 1, 0, -1)
                            + option(4, b"packet-capture-shipper pcap-annotate.py")
                            + struct.pack("<HH", 0, 0)))
            # Interface Description Block; if_tsresol 9 = nanoseconds, 6 = microseconds.
            out.write(block(0x00000001,
                            struct.pack("<HHI", linktype, 0, snaplen)
                            + option(9, bytes([9 if nanos else 6]))
                            + struct.pack("<HH", 0, 0)))
            unit = 10**9 if nanos else 10**6
            while True:
                rec = f.read(16)
                if not rec:
                    break
                if len(rec) < 16:
                    break                 # tcpdump -U: a partial final record, drop it
                sec, frac, incl, orig = struct.unpack(e + "IIII", rec)
                data = f.read(incl)
                if len(data) < incl:
                    break
                ts = sec * unit + frac
                body = struct.pack("<IIIII", 0, ts >> 32, ts & 0xFFFFFFFF, incl, orig) + pad4(data)
                s, d = endpoints(linktype, data)
                if s:
                    text = "src %s %s -> dst %s %s" % (
                        s, names.get(s, "external"), d, names.get(d, "external"))
                    body += option(1, text.encode()) + struct.pack("<HH", 0, 0)
                out.write(block(0x00000006, body))
                n += 1
        os.replace(tmp, dst)
    print("%s: %d packets annotated" % (dst, n))


if __name__ == "__main__":
    main()
