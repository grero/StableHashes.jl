function shash(X::AbstractArray{T}, h::UInt64) where T
	for x in X
		h = shash(x,h)
	end
	h
end
