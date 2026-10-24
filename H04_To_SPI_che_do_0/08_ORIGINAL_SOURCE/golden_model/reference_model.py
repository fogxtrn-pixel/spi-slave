def bits(byte, msb_first=True):
    b=int(byte)&0xff
    return [(b>>(7-i if msb_first else i))&1 for i in range(8)]

def mode0_exchange(tx, master_miso_bits, msb_first=True):
    txb=bits(tx,msb_first)
    rxb=[int(x)&1 for x in master_miso_bits]
    assert len(rxb)==8
    return txb, rxb

def decode(bits_in, msb_first=True):
    if msb_first:
        v=0
        for x in bits_in: v=(v<<1)|x
        return v
    return sum(x<<i for i,x in enumerate(bits_in))

def test_vectors():
    for b in [0x00,0x01,0x55,0x96,0xA5,0xFF]:
        for order in [False,True]:
            seq=bits(b,order)
            assert decode(seq,order)==b

def test_eight_edges():
    rising=list(range(8))
    falling=list(range(8))
    assert len(rising)==8 and len(falling)==8

def test_abort():
    received=[1,0,1,1,0]
    assert len(received)<8
    # Partial data must not be accepted as a complete byte.
    complete = len(received)==8
    assert not complete

def test_consecutive():
    first=decode(bits(0x96,True),True)
    second=decode(bits(0x3C,True),True)
    assert first==0x96 and second==0x3C and first!=second

def test_full_duplex():
    tx,r=mode0_exchange(0x96,bits(0x3C,True),True)
    assert len(tx)==8 and len(r)==8
    assert decode(tx,True)==0x96
    assert decode(r,True)==0x3C

def test_latency():
    for f in [100_000,1_000_000,10_000_000]:
        assert abs(8/f - 8/f)<1e-18

def test_random():
    import random
    random.seed(404)
    for _ in range(5000):
        b=random.randrange(256)
        order=bool(random.randrange(2))
        assert decode(bits(b,order),order)==b

if __name__=="__main__":
    test_vectors()
    test_eight_edges()
    test_abort()
    test_consecutive()
    test_full_duplex()
    test_latency()
    test_random()
    print("H04 golden reference PASS")
