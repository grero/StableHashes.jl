## shashing small, built-in numeric types ##
using Base: fptoui

hx(a::UInt64, b::Float64, h::UInt) = shash_uint64((3a + reinterpret(UInt64,b)) - h)
const hx_NaN = hx(UInt64(0), NaN, UInt(0  ))

shash(x::UInt64,  h::UInt) = hx(x, Float64(x), h)
shash(x::Int64,   h::UInt) = hx(reinterpret(UInt64, abs(x)), Float64(x), h)
shash(x::Float64, h::UInt) = isnan(x) ? (hx_NaN ⊻ h) : hx(fptoui(UInt64, abs(x)), x, h)

shash(x::Union{Bool,Int8,UInt8,Int16,UInt16,Int32,UInt32}, h::UInt) = shash(Int64(x), h)
shash(x::Float32, h::UInt) = shash(Float64(x), h)
