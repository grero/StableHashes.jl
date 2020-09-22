# This file is a part of Julia. License is MIT: https://julialang.org/license

## efficient value-based shashing of integers ##
function shash_integer(n::Integer, h::UInt)
    h ⊻= shash_uint((n % UInt) ⊻ h)
    n = abs(n)
    n >>>= sizeof(UInt) << 3
    while n != 0
        h ⊻= shash_uint((n % UInt) ⊻ h)
        n >>>= sizeof(UInt) << 3
    end
    return h
end

function shash_integer(n::BigInt, h::UInt)
    s = n.size
    s == 0 && return shash_integer(0, h)
    p = convert(Ptr{UInt}, n.d)
    b = unsafe_load(p)
    h ⊻= shash_uint(ifelse(s < 0, -b, b) ⊻ h)
    for k = 2:abs(s)
        h ⊻= shash_uint(unsafe_load(p, k) ⊻ h)
    end
    return h
end

## generic shashing for rational values ##

function shash(x::Real, h::UInt)
    # decompose x as num*2^pow/den
    num, pow, den = decompose(x)

    # handle special values
    num == 0 && den == 0 && return shash(NaN, h)
    num == 0 && return shash(ifelse(den > 0, 0.0, -0.0), h)
    den == 0 && return shash(ifelse(num > 0, Inf, -Inf), h)

    # normalize decomposition
    if den < 0
        num = -num
        den = -den
    end
    z = trailing_zeros(num)
    if z != 0
        num >>= z
        pow += z
    end
    z = trailing_zeros(den)
    if z != 0
        den >>= z
        pow -= z
    end

    # handle values representable as Int64, UInt64, Float64
    if den == 1
        left = ndigits0z(num,2) + pow
        right = trailing_zeros(num) + pow
        if -1074 <= right
            if 0 <= right && left <= 64
                left <= 63                     && return shash(Int64(num) << Int(pow), h)
                signbit(num) == signbit(den)   && return shash(UInt64(num) << Int(pow), h)
            end # typemin(Int64) handled by Float64 case
            left <= 1024 && left - right <= 53 && return shash(ldexp(Float64(num),pow), h)
        end
    end

    # handle generic rational values
    h = shash_integer(den, h)
    h = shash_integer(pow, h)
    h = shash_integer(num, h)
    return h
end

#=
`decompose(x)`: non-canonical decomposition of rational values as `num*2^pow/den`.

The decompose function is the point where rational-valued numeric types that support
shashing hook into the shashing protocol. `decompose(x)` should return three integer
values `num, pow, den`, such that the value of `x` is mathematically equal to

    num*2^pow/den

The decomposition need not be canonical in the sense that it just needs to be *some*
way to express `x` in this form, not any particular way – with the restriction that
`num` and `den` may not share any odd common factors. They may, however, have powers
of two in common – the generic shashing code will normalize those as necessary.

Special values:

 - `x` is zero: `num` should be zero and `den` should have the same sign as `x`
 - `x` is infinite: `den` should be zero and `num` should have the same sign as `x`
 - `x` is not a number: `num` and `den` should both be zero
=#

decompose(x::Integer) = x, 0, 1
decompose(x::Rational) = numerator(x), 0, denominator(x)

function decompose(x::Float16)::NTuple{3,Int}
    isnan(x) && return 0, 0, 0
    isinf(x) && return ifelse(x < 0, -1, 1), 0, 0
    n = reinterpret(UInt16, x)
    s = (n & 0x03ff) % Int16
    e = ((n & 0x7c00) >> 10) % Int
    s |= Int16(e != 0) << 10
    d = ifelse(signbit(x), -1, 1)
    s, e - 25 + (e == 0), d
end

function decompose(x::Float32)::NTuple{3,Int}
    isnan(x) && return 0, 0, 0
    isinf(x) && return ifelse(x < 0, -1, 1), 0, 0
    n = reinterpret(UInt32, x)
    s = (n & 0x007fffff) % Int32
    e = ((n & 0x7f800000) >> 23) % Int
    s |= Int32(e != 0) << 23
    d = ifelse(signbit(x), -1, 1)
    s, e - 150 + (e == 0), d
end

function decompose(x::Float64)::Tuple{Int64, Int, Int}
    isnan(x) && return 0, 0, 0
    isinf(x) && return ifelse(x < 0, -1, 1), 0, 0
    n = reinterpret(UInt64, x)
    s = (n & 0x000fffffffffffff) % Int64
    e = ((n & 0x7ff0000000000000) >> 52) % Int
    s |= Int64(e != 0) << 52
    d = ifelse(signbit(x), -1, 1)
    s, e - 1075 + (e == 0), d
end

function decompose(x::BigFloat)::Tuple{BigInt, Int, Int}
    isnan(x) && return 0, 0, 0
    isinf(x) && return x.sign, 0, 0
    x == 0 && return 0, 0, x.sign
    s = BigInt()
    s.size = cld(x.prec, 8*sizeof(GMP.Limb)) # limbs
    b = s.size * sizeof(GMP.Limb)            # bytes
    ccall((:__gmpz_realloc2, :libgmp), Cvoid, (Ref{BigInt}, Culong), s, 8b) # bits
    ccall(:memcpy, Ptr{Cvoid}, (Ptr{Cvoid}, Ptr{Cvoid}, Csize_t), s.d, x.d, b) # bytes
    s, x.exp - 8b, x.sign
end

## streamlined shashing for smallish rational types ##

function shash(x::Rational{<:BitInteger64}, h::UInt)
    num, den = Base.numerator(x), Base.denominator(x)
    den == 1 && return shash(num, h)
    den == 0 && return shash(ifelse(num > 0, Inf, -Inf), h)
    if isodd(den)
        pow = trailing_zeros(num)
        num >>= pow
    else
        pow = trailing_zeros(den)
        den >>= pow
        pow = -pow
        if den == 1 && abs(num) < 9007199254740992
            return shash(ldexp(Float64(num),pow),h)
        end
    end
    h = shash_integer(den, h)
    h = shash_integer(pow, h)
    h = shash_integer(num, h)
    return h
end

## shashing Float16s ##

shash(x::Float16, h::UInt) = shash(Float64(x), h)

## shashing strings ##

const memshash = UInt === UInt64 ? :memhash_seed : :memhash32_seed
const memshash_seed = UInt === UInt64 ? 0x71e729fd56419c81 : 0x56419c81

function shash(s::Union{String,SubString{String}}, h::UInt)
    h += memshash_seed
    # note: use pointer(s) here (see #6058).
    ccall(memshash, UInt, (Ptr{UInt8}, Csize_t, UInt32), pointer(s), sizeof(s), h % UInt32) + h
end
shash(s::AbstractString, h::UInt) = shash(String(s), h)
