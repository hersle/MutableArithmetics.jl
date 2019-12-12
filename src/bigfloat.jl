mutability(::Type{BigFloat}) = IsMutable()
mutable_copy(x::BigFloat) = deepcopy(x)

# zero
promote_operation(::typeof(zero), ::Type{BigFloat}) = BigFloat
function _set_si!(x::BigFloat, value)
    ccall((:mpfr_set_si, :libmpfr), Int32, (Ref{BigFloat}, Clong, Base.MPFR.MPFRRoundingMode), x, value, Base.MPFR.ROUNDING_MODE[])
    return x
end
mutable_operate!(::typeof(zero), x::BigFloat) = _set_si!(x, 0)

# one
promote_operation(::typeof(one), ::Type{BigFloat}) = BigFloat
mutable_operate!(::typeof(one), x::BigFloat) = _set_si!(x, 1)

# +
promote_operation(::typeof(+), ::Vararg{Type{BigFloat}, N}) where {N} = BigFloat
function mutable_operate_to!(output::BigFloat, ::typeof(+), a::BigFloat, b::BigFloat)
    ccall((:mpfr_add, :libmpfr), Int32, (Ref{BigFloat}, Ref{BigFloat}, Ref{BigFloat}, Base.MPFR.MPFRRoundingMode), output, a, b, Base.MPFR.ROUNDING_MODE[])
    return output
end
#function mutable_operate_to!(output::BigFloat, op::typeof(+), a::BigFloat, b::LinearAlgebra.UniformScaling)
#    return mutable_operate_to!(output, op, a, b.λ)
#end

# *
promote_operation(::typeof(*), ::Vararg{Type{BigFloat}, N}) where {N} = BigFloat
function mutable_operate_to!(output::BigFloat, ::typeof(*), a::BigFloat, b::BigFloat)
    ccall((:mpfr_mul, :libmpfr), Int32, (Ref{BigFloat}, Ref{BigFloat}, Ref{BigFloat}, Base.MPFR.MPFRRoundingMode), output, a, b, Base.MPFR.ROUNDING_MODE[])
    return output
end

function mutable_operate_to!(output::BigFloat, op::Union{typeof(*), typeof(+)},
                             a::BigFloat, b::BigFloat, c::Vararg{BigFloat, N}) where N
    mutable_operate_to!(output, op, a, b)
    return mutable_operate!(op, output, c...)
end
function mutable_operate!(op::Function, x::BigFloat, args::Vararg{Any, N}) where N
    mutable_operate_to!(x, op, x, args...)
end

# add_mul
# Buffer to hold the product
buffer_for(::typeof(add_mul), args::Vararg{Type{BigFloat}, N}) where {N} = BigFloat()
function mutable_operate_to!(output::BigFloat, ::typeof(add_mul), x::BigFloat, y::BigFloat, z::BigFloat, args::Vararg{BigFloat, N}) where N
    return mutable_buffered_operate_to!(BigFloat(), output, add_mul, x, y, z, args...)
end

function mutable_buffered_operate_to!(buffer::BigFloat, output::BigFloat, ::typeof(add_mul),
                                      a::BigFloat, x::BigFloat, y::BigFloat, args::Vararg{BigFloat, N}) where N
    mutable_operate_to!(buffer, *, x, y, args...)
    return mutable_operate_to!(output, +, a, buffer)
end
function mutable_buffered_operate!(buffer::BigFloat, op::typeof(add_mul), x::BigFloat, args::Vararg{Any, N}) where N
    return mutable_buffered_operate_to!(buffer, x, op, x, args...)
end

scaling_to_bigfloat(x::BigFloat) = x
scaling_to_bigfloat(x::Number) = convert(BigFloat, x)
scaling_to_bigfloat(J::LinearAlgebra.UniformScaling) = scaling_to_bigfloat(J.λ)
function mutable_operate_to!(output::BigFloat, op::Union{typeof(+), typeof(*)}, args::Vararg{Scaling, N}) where N
    return mutable_operate_to!(output, op, scaling_to_bigfloat.(args)...)
end
function mutable_operate_to!(output::BigFloat, op::typeof(add_mul), x::Scaling, y::Scaling, z::Scaling, args::Vararg{Scaling, N}) where N
    return mutable_operate_to!(
        output, op, scaling_to_bigfloat(x), scaling_to_bigfloat(y),
        scaling_to_bigfloat(z), scaling_to_bigfloat.(args)...)
end
# Called for instance if `args` is `(v', v)` for a vector `v`.
function mutable_operate_to!(output::BigFloat, op::typeof(add_mul), x, y, z, args::Vararg{Any, N}) where N
    return mutable_operate_to!(output, +, x, *(y, z, args...))
end
