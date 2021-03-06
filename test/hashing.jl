# This file is a part of Julia. License is MIT: https://julialang.org/license

using Random, LinearAlgebra, SparseArrays

types = Any[
    Bool,
    Int8, UInt8, Int16, UInt16, Int32, UInt32, Int64, UInt64, Float32, Float64,
    Rational{Int8}, Rational{UInt8}, Rational{Int16}, Rational{UInt16},
    Rational{Int32}, Rational{UInt32}, Rational{Int64}, Rational{UInt64}
]
vals = vcat(
    typemin(Int64),
    -Int64(maxintfloat(Float64)) .+ Int64[-4:1;],
    typemin(Int32),
    -Integer(maxintfloat(Float32)) .+ (-4:1),
    -2:2,
    Integer(maxintfloat(Float32)) .+ (-1:4),
    typemax(Int32),
    Int64(maxintfloat(Float64)) .+ Int64[-1:4;],
    typemax(Int64),
)

function coerce(T::Type, x)
    if T<:Rational
        convert(T, coerce(typeof(numerator(zero(T))), x))
    elseif !(T<:Integer)
        convert(T, x)
    else
        x % T
    end
end

for T = types[2:end],
    x = vals,
    a = coerce(T, x)
    @test shash(a,zero(UInt)) == invoke(shash, Tuple{Real, UInt}, a, zero(UInt))
    @test shash(a,one(UInt)) == invoke(shash, Tuple{Real, UInt}, a, one(UInt))
end

for T = types,
    S = types,
    x = vals,
    a = coerce(T, x),
    b = coerce(S, x)
    #println("$(typeof(a)) $a")
    #println("$(typeof(b)) $b")
    @test isequal(a,b) == (shash(a)==shash(b))
    # for y=vals
    #     println("T=$T; S=$S; x=$x; y=$y")
    #     c = convert(T,x//y)
    #     d = convert(S,x//y)
    #     @test !isequal(a,b) || shash(a)==shash(b)
    # end
end

# issue #8619
@test shash(nextfloat(2.0^63)) == shash(UInt64(nextfloat(2.0^63)))
@test shash(prevfloat(2.0^64)) == shash(UInt64(prevfloat(2.0^64)))

# issue #9264
@test shash(1//6,zero(UInt)) == invoke(shash, Tuple{Real, UInt}, 1//6, zero(UInt))
@test shash(1//6) == shash(big(1)//big(6))
@test shash(1//6) == shash(0x01//0x06)

# shashing collections (e.g. issue #6870)
vals = Any[
    [1,2,3,4], [1 3;2 4], Any[1,2,3,4], [1,3,2,4],
    [1.0, 2.0, 3.0, 4.0], BigInt[1, 2, 3, 4],
    [1,0], [true,false], BitArray([true,false]),
    # Irrationals
    Any[1, pi], [1, pi], [pi, pi], Any[pi, pi],
    # Overflow with Int8
    Any[Int8(127), Int8(-128), -383], 127:-255:-383,
    # Loss of precision with Float64
    Any[-Int64(2)^53-1, 0.0, Int64(2)^53+1], [-Int64(2)^53-1, 0, Int64(2)^53+1],
        (-Int64(2)^53-1):Int64(2)^53+1:(Int64(2)^53+1),
    # Some combinations of elements support -, others do not
    [1, 2, "a"], [1, "a", 2], [1, 2, "a", 2], [1, 'a', 2],
    Set([1,2,3,4]),
    Set([1:10;]),                # these lead to different key orders
    Set([7,9,4,10,2,3,5,8,6,1]), #
    Dict(42 => 101, 77 => 93), Dict{Any,Any}(42 => 101, 77 => 93),
    (1,2,3,4), (1.0,2.0,3.0,4.0), (1,3,2,4),
    ("a","b"), (SubString("a",1,1), SubString("b",1,1)),
    # issue #6900
    Dict(x => x for x in 1:10),
    Dict(7=>7,9=>9,4=>4,10=>10,2=>2,3=>3,8=>8,5=>5,6=>6,1=>1),
    [], [1], [2], [1, 1], [1, 2], [1, 3], [2, 2], [1, 2, 2], [1, 3, 3],
    zeros(2, 2), spzeros(2, 2), Matrix(1.0I, 2, 2), sparse(1.0I, 2, 2),
    sparse(fill(1., 2, 2)), fill(1., 2, 2), sparse([0 0; 1 0]), [0 0; 1 0],
    [-0. 0; -0. 0.], SparseMatrixCSC(2, 2, [1, 3, 3], [1, 2], [-0., -0.]),
    # issue #16364
    1:4, 1:1:4, 1:-1:0, 1.0:4.0, 1.0:1.0:4.0, range(1, stop=4, length=4),
    'a':'e', ['a', 'b', 'c', 'd', 'e'],
    # check that shash is still consistent with heterogeneous arrays for which - is defined
    # for some pairs and not others
    ["a", "b", 1, 2], ["a", 1, 2], ["a", "b", 2, 2], ["a", "a", 1, 2], ["a", "b", 2, 3]
]

for a in vals
    if a isa AbstractArray
        @test shash(a) == shash(Array(a)) == shash(Array{Any}(a))
    end
end

vals = Any[
    Int[], Float64[],
    [0], [1], [2],
    # test vectors starting with ranges
    [1, 2], [1, 2, 3], [1, 2, 3, 4], [1, 2, 3, 4, 5], [1, 2, 3, 4, 5, 6],
    [2, 1], [3, 2, 1], [4, 3, 2, 1], [5, 4, 3, 2, 1], [5, 4, 3, 2, 1, 0, -1],
    # test vectors starting with ranges which trigger overflow with Int8
    [124, 125, 126, 127], [124, 125, 126, 127, -128], [-128, 127, -128],
    # test vectors including ranges
    [2, 1, 2, 3], [2, 3, 2, 1], [2, 1, 2, 3, 2], [2, 3, 2, 1, 2],
    # test various sparsity patterns
    [0, 0], [0, 0, 0], [0, 1], [1, 0],
    [0, 0, 1], [0, 1, 0], [1, 0, 0], [0, 1, 2],
    [0 0; 0 0], [1 0; 0 0], [0 1; 0 0], [0 0; 1 0], [0 0; 0 1],
    [5 1; 0 0], [1 1; 0 1], [0 2; 3 0], [0 2; 4 6], [4 0; 0 1],
    [0 0 0; 0 0 0], [1 0 0; 0 0 1], [0 0 2; 3 0 0], [0 0 7; 6 1 2],
    [4 0 0; 3 0 1], [0 2 4; 6 0 0],
    # various stored zeros patterns
    sparse([1], [1], [0]), sparse([1], [1], [-0.0]),
    sparse([1, 2], [1, 1], [-0.0, 0.0]), sparse([1, 2], [1, 1], [0.0, -0.0]),
    sparse([1, 2], [1, 1], [-0.0, 0.0], 3, 1), sparse([1, 2], [1, 1], [0.0, -0.0], 3, 1),
    sparse([1, 3], [1, 1], [-0.0, 0.0], 3, 1), sparse([1, 3], [1, 1], [0.0, -0.0], 3, 1),
    sparse([1, 2, 3], [1, 1, 1], [-1, 0, 1], 3, 1), sparse([1, 2, 3], [1, 1, 1], [-1.0, -0.0, 1.0], 3, 1),
    sparse([1, 3], [1, 1], [-1, 0], 3, 1), sparse([1, 2], [1, 1], [-1, 0], 3, 1)
]

for a in vals
    b = Array(a)
    @test shash(convert(Array{Any}, a)) == shash(b)
    @test shash(convert(Array{supertype(eltype(a))}, a)) == shash(b)
    @test shash(convert(Array{Float64}, a)) == shash(b)
    @test shash(sparse(a)) == shash(b)
    if !any(x -> isequal(x, -0.0), a)
        @test shash(convert(Array{Int}, a)) == shash(b)
        if all(x -> typemin(Int8) <= x <= typemax(Int8), a)
            @test shash(convert(Array{Int8}, a)) == shash(b)
        end
    end
end

# Test that overflow does not give inconsistent shashes with heterogeneous arrays
@test shash(Any[Int8(1), Int8(2), 255]) == shash([1, 2, 255])
@test shash(Any[Int8(127), Int8(-128), 129, 130]) ==
    shash([127, -128, 129, 130]) != shash([127,  128, 129, 130])

# Test shashing sparse matrix with type which does not support -
struct CustomHashReal
    x::Float64
end
StableHashes.shash(x::CustomHashReal, h::UInt) = shash(x.x, h)
Base.zero(::Type{CustomHashReal}) = CustomHashReal(0.0)
Base.zero(x::CustomHashReal) = zero(CustomHashReal)

let a = sparse([CustomHashReal(0), CustomHashReal(3), CustomHashReal(3)])
    @test shash(a) == shash(Array(a))
end

vals = Any[
    0.0:0.1:0.3, 0.3:-0.1:0.0,
    0:-1:1, 0.0:-1.0:1.0, 0.0:1.1:10.0, -4:10,
    'a':'e', 'b':'a',
    range(1, stop=1, length=1), range(0.3, stop=1.0, length=3),  range(1, stop=1.1, length=20)
]

for a in vals
    @test shash(Array(a)) == shash(a)
end

@test shash(SubString("--hello--",3,7)) == shash("hello")
@test shash(:(X.x)) == shash(:(X.x))
@test shash(:(X.x)) != shash(:(X.y))

@test shash([1,2]) == shash(view([1,2,3,4],1:2))

let a = QuoteNode(1), b = QuoteNode(1.0)
    @test (shash(a)==shash(b)) == (a==b)
end

let a = Expr(:block, Core.TypedSlot(1, Any)),
    b = Expr(:block, Core.TypedSlot(1, Any)),
    c = Expr(:block, Core.TypedSlot(3, Any))
    @test a == b && shash(a) == shash(b)
    @test a != c && shash(a) != shash(c)
    @test b != c && shash(b) != shash(c)
end

@test shash(Dict(),shash(Set())) != shash(Set(),shash(Dict()))

# issue 15659
for prec in [3, 11, 15, 16, 31, 32, 33, 63, 64, 65, 254, 255, 256, 257, 258, 1023, 1024, 1025],
    v in Any[-0.0, 0, 1, -1, 1//10, 2//10, 3//10, 1//2, pi]
    setprecision(prec) do
        x = convert(BigFloat, v)
        @test precision(x) == prec
        num, pow, den = Base.decompose(x)
        y = num*big(2.0)^pow/den
        @test precision(y) == prec
        @test isequal(x, y)
    end
end

# issue #20744
@test shash(:c, shash(:b, shash(:a))) != shash(:a, shash(:b, shash(:c)))

# issue #5849, objectid of types
@test Vector === (Array{T,1} where T)
@test (Pair{A,B} where A where B) !== (Pair{A,B} where B where A)
let vals_expr = :(Any[Vector, (Array{T,1} where T), 1, 2, Union{Int, String}, Union{String, Int},
                      (Union{String, T} where T), Ref{Ref{T} where T}, (Ref{Ref{T}} where T),
                      (Vector{T} where T<:Real), (Vector{T} where T<:Integer),
                      (Vector{T} where T>:Integer),
                      (Pair{A,B} where A where B), (Pair{A,B} where B where A)])
    vals_a = eval(vals_expr)
    vals_b = eval(vals_expr)
    for (i, a) in enumerate(vals_a), (j, b) in enumerate(vals_b)
        @test i != j || (a === b)
        @test (a === b) == (objectid(a) == objectid(b))
    end
end

# issue #26038
let p1 = Ptr{Int8}(1), p2 = Ptr{Int32}(1), p3 = Ptr{Int8}(2)
    @test p1 == p2
    @test !isequal(p1, p2)
    @test p1 != p3
    @test shash(p1) != shash(p2)
    @test shash(p1) != shash(p3)
    @test shash(p1) == shash(Ptr{Int8}(1))

    @test p1 < p3
    @test !(p1 < p2)
    @test isless(p1, p3)
    @test_throws MethodError isless(p1, p2)
end


# specific values
ss = ["the","quick","brown","fox","jumped","over","the","lazy","dog"]
@test shash(ss) == 0xebbdec378ca68ecb
bb = [1, 1.0, 4.5, 2]
@test shash(bb) == 0xc8956d61875e33a8
@test shash(1:5) == 0x7523ed0aee65cb92
@test shash(1=>2) == 0x3fd8c7581d9d7bdc

if Base.VERSION < v"1.5.0"
	@test shash(ss[1]) == hash(ss[1])
	@test shash(ss) == hash(ss)
	@test shash(bb) == hash(bb)
	@test shash(1:5) == hash(1:5)
	@test shash(1=>2) == hash(1=>2)
end

#multidmensional array
Y = fill(0.0, 3,4,5)
Y[:,:,1] .= [0.2403493931933327 0.11411875979049779 0.04336592893368052 0.3760437294104595; 0.2113416496139997 0.7865756852036974 0.22765868200809725 0.4430163540933343; 0.6486074461580857 0.5387061418118246 0.1731547177534829 0.5596720308043552]

Y[:,:,2] .= [0.923380761211867 0.054013162677462256 0.7183646624928159 0.004242719144976759; 0.48132417919500536 0.9498195541020931 0.4733055195739646 0.394629131548335; 0.49548006920885945 0.022872455006747616 0.14566423166710396 0.17505672861983412]

Y[:,:,3] .= [0.46703306908623854 0.4108729721391191 0.825627977504352 0.9325188027606299; 0.3835979657341353 0.5275712168844051 0.07368290736771899 0.19743116340673494; 0.33918051010330297 0.8654489325312786 0.5037639137495875 0.2702962675721432]

Y[:,:,4] = [0.46210090187649655 0.6063162072865642 0.35911156071254924 0.49800852069717627; 0.6486385056321007 0.05715914463678806 0.0557211734502594 0.6961427490956922; 0.8047935432736606 0.31010624397297604 0.6310724719178 0.35017644748941823]

Y[:,:,5] .= [0.07449108387688508 0.3420859368181419 0.4203900122479969 0.5190705606397219; 0.012668199487784193 0.3269594862612726 0.6237635825975416 0.3499728719023023; 0.7951085163647378 0.899073178977049 0.9327255281933302 0.2059998844846087]

@test shash(Y) == 0xd810e18c9b9ed690
if Base.VERSION < v"1.5.0"
	@test shash(Y) == hash(Y)
end
