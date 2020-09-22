shash(p::Pair, h::UInt) = shash(p.second, shash(p.first, h))
