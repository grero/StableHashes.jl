const tupleshash_seed = UInt === UInt64 ? 0x77cfa1eef01bca90 : 0xf01bca90
shash(::Tuple{}, h::UInt) = h + tupleshash_seed
shash(t::Tuple, h::UInt) = shash(t[1], shash(Base.tail(t), h))
const Any16{N} = Tuple{Any,Any,Any,Any,Any,Any,Any,Any,
				   Any,Any,Any,Any,Any,Any,Any,Any,Vararg{Any,N}}
function shash(t::Any16, h::UInt)
    out = h + tupleshash_seed
    for i = length(t):-1:1
        out = shash(t[i], out)
    end
    return out
end
