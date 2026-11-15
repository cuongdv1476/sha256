#!/usr/bin/env python3
"""Small bit-accurate SHA-256 oracle used to independently validate the SV model.

Byte-aligned cases are cross-checked against Python's hashlib implementation.
The packed message format is MSB-first; unused low bits in the last byte are zero.
"""
from __future__ import annotations
import hashlib
import json
from pathlib import Path

K = [
0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,
0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,
0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,
0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,
0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,
0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,
0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,
0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2]
IV = [0x6a09e667,0xbb67ae85,0x3c6ef372,0xa54ff53a,0x510e527f,0x9b05688c,0x1f83d9ab,0x5be0cd19]
MASK = 0xffffffff

def ror(x: int, n: int) -> int:
    return ((x >> n) | (x << (32-n))) & MASK

def sha256_bits(bits: list[int]) -> bytes:
    n = len(bits)
    padded = list(bits) + [1]
    padded.extend([0] * ((448 - len(padded)) % 512))
    padded.extend((n >> i) & 1 for i in range(63, -1, -1))
    h = IV.copy()
    for off in range(0, len(padded), 512):
        block = padded[off:off+512]
        w = [sum(block[t*32+j] << (31-j) for j in range(32)) for t in range(16)]
        for t in range(16,64):
            x,y=w[t-15],w[t-2]
            s0=ror(x,7)^ror(x,18)^(x>>3)
            s1=ror(y,17)^ror(y,19)^(y>>10)
            w.append((w[t-16]+s0+w[t-7]+s1)&MASK)
        a,b,c,d,e,f,g,hh=h
        for t in range(64):
            S1=ror(e,6)^ror(e,11)^ror(e,25)
            ch=(e&f)^((~e)&g)
            t1=(hh+S1+ch+K[t]+w[t])&MASK
            S0=ror(a,2)^ror(a,13)^ror(a,22)
            maj=(a&b)^(a&c)^(b&c)
            t2=(S0+maj)&MASK
            a,b,c,d,e,f,g,hh=(t1+t2)&MASK,a,b,c,(d+t1)&MASK,e,f,g
        h=[(x+y)&MASK for x,y in zip(h,[a,b,c,d,e,f,g,hh])]
    return b''.join(x.to_bytes(4,'big') for x in h)

def pack(bits: list[int]) -> bytes:
    out=bytearray((len(bits)+7)//8)
    for i,b in enumerate(bits): out[i//8] |= b << (7-(i%8))
    return bytes(out)

def pattern(n: int) -> list[int]:
    return [((i*17 + (i>>3)*5) ^ (i>>1)) & 1 for i in range(n)]

def main() -> None:
    cases={"empty":[],"abc":[(x>>(7-i))&1 for x in b"abc" for i in range(8)],
           "one_bit":[1],"nine_bit":[1,0,1,1,0,1,0,0,1]}
    for n in (447,448,449,511,512,513,895,896,897,1023,1024,1025):
        cases[f"pattern_{n}"]=pattern(n)
    cases["bytes_0_to_127"]=[(x>>(7-i))&1 for x in bytes(range(128)) for i in range(8)]
    output=[]
    for name,bits in cases.items():
        digest=sha256_bits(bits)
        if len(bits)%8==0:
            ref=hashlib.sha256(pack(bits)).digest()
            assert digest==ref, f"hashlib mismatch: {name}"
        output.append({"name":name,"bit_length":len(bits),"message_msb_hex":pack(bits).hex(),"sha256":digest.hex()})
    target=Path(__file__).with_name("sha256_independent_vectors.json")
    target.write_text(json.dumps({"oracle":"Python bit-level implementation cross-checked with hashlib for byte-aligned cases","vectors":output},indent=2)+"\n")
    for item in output: print(f"{item['name']} {item['bit_length']} {item['sha256']}")
    print(f"PASS: {len(output)} vectors; byte-aligned cases matched hashlib")

if __name__=="__main__": main()
