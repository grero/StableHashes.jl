# This file is a part of Julia. License is MIT: https://julialang.org/license

## shashing a single value ##

"""
    shash(x[, h::UInt])

Compute an integer shash code such that `isequal(x,y)` implies `shash(x)==shash(y)`. The
optional second argument `h` is a shash code to be mixed with the result.

New types should implement the 2-argument form, typically by calling the 2-argument `shash`
method recursively in order to mix shashes of the contents with each other (and with `h`).
Typically, any type that implements `shash` should also implement its own `==` (hence
`isequal`) to guarantee the property mentioned above. Types supporting subtraction
(operator `-`) should also implement [`widen`](@ref), which is required to shash
values inside heterogeneous arrays.
"""
shash(x::Any) = shash(x, zero(UInt))
shash(w::WeakRef, h::UInt) = shash(w.value, h)

## shashing general objects ##

shash(@nospecialize(x), h::UInt) = shash_uint(3h - objectid(x))

## core data shashing functions ##

function shash_64_64(n::UInt64)
    a::UInt64 = n
    a = ~a + a << 21
    a =  a ⊻ a >> 24
    a =  a + a << 3 + a << 8
    a =  a ⊻ a >> 14
    a =  a + a << 2 + a << 4
    a =  a ⊻ a >> 28
    a =  a + a << 31
    return a
end

function shash_64_32(n::UInt64)
    a::UInt64 = n
    a = ~a + a << 18
    a =  a ⊻ a >> 31
    a =  a * 21
    a =  a ⊻ a >> 11
    a =  a + a << 6
    a =  a ⊻ a >> 22
    return a % UInt32
end

function shash_32_32(n::UInt32)
    a::UInt32 = n
    a = a + 0x7ed55d16 + a << 12
    a = a ⊻ 0xc761c23c ⊻ a >> 19
    a = a + 0x165667b1 + a << 5
    a = a + 0xd3a2646c ⊻ a << 9
    a = a + 0xfd7046c5 + a << 3
    a = a ⊻ 0xb55a4f09 ⊻ a >> 16
    return a
end

if UInt === UInt64
    shash_uint64(x::UInt64) = shash_64_64(x)
    shash_uint(x::UInt)     = shash_64_64(x)
else
    shash_uint64(x::UInt64) = shash_64_32(x)
    shash_uint(x::UInt)     = shash_32_32(x)
end

## symbol & expression shashing ##

if UInt === UInt64
    shash(x::Expr, h::UInt) = shash(x.args, shash(x.head, h + 0x83c7900696d26dc6))
    shash(x::QuoteNode, h::UInt) = shash(x.value, h + 0x2c97bf8b3de87020)
else
    shash(x::Expr, h::UInt) = shash(x.args, shash(x.head, h + 0x96d26dc6))
    shash(x::QuoteNode, h::UInt) = shash(x.value, h + 0x469d72af)
end
