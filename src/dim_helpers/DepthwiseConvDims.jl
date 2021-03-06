export DepthwiseConvDims

"""
    DepthwiseConvDims

Concrete subclass of `ConvDims` for a depthwise convolution.  Differs primarily due to
characterization by C_in, C_mult, rather than C_in, C_out.  Useful to be separate from
DenseConvDims primarily for channel calculation differences.
"""
struct DepthwiseConvDims{N,K,C_in,C_mult,S,P,D,F} <: ConvDims{N,S,P,D,F}
    I::NTuple{N, Int}
end

# Getters for the fields
input_size(c::DepthwiseConvDims) = c.I
kernel_size(c::DepthwiseConvDims{N,K,C_in,C_mult,S,P,D,F}) where {N,K,C_in,C_mult,S,P,D,F} = K
channels_in(c::DepthwiseConvDims{N,K,C_in,C_mult,S,P,D,F}) where {N,K,C_in,C_mult,S,P,D,F} = C_in
channels_out(c::DepthwiseConvDims{N,K,C_in,C_mult,S,P,D,F}) where {N,K,C_in,C_mult,S,P,D,F} = C_in * C_mult
channel_multiplier(c::DepthwiseConvDims{N,K,C_in,C_mult,S,P,D,F}) where {N,K,C_in,C_mult,S,P,D,F} = C_mult


# Convenience wrapper to create DepthwiseConvDims objects
function DepthwiseConvDims(x_size::NTuple{M}, w_size::NTuple{M};
                           stride=1, padding=0, dilation=1, flipkernel::Bool=false) where M
    # Do common parameter validation
    stride, padding, dilation = check_spdf(x_size, w_size, stride, padding, dilation)

    # Ensure channels are equal
    if x_size[end-1] != w_size[end]
        xs = x_size[end-1]
        ws = w_size[end]
        throw(DimensionMismatch("Input channels must match! ($xs vs. $ws)"))
    end
    
    return DepthwiseConvDims{
        M - 2,
        # Kernel spatial size
        w_size[1:end-2],
        # Input channels
        x_size[end-1],
        # Channel multiplier
        w_size[end-1],
        stride,
        padding,
        dilation,
        flipkernel
    }(
        # Image spatial size
        x_size[1:end-2],
    )
end

# Auto-extract sizes and just pass those directly in
function DepthwiseConvDims(x::AbstractArray, w::AbstractArray; kwargs...)
    if ndims(x) != ndims(w)
        throw(DimensionMismatch("Rank of x and w must match! ($(ndims(x)) vs. $(ndims(w)))"))
    end
    return DepthwiseConvDims(size(x), size(w); kwargs...)
end

# Useful for constructing a new DepthwiseConvDims that has only a few elements different
# from the original progenitor object.
function DepthwiseConvDims(c::DepthwiseConvDims; N=spatial_dims(c), I=input_size(c), K=kernel_size(c),
                           C_in=channels_in(c), C_m=channel_multiplier(c), S=stride(c),
                           P=padding(c), D=dilation(c), F=flipkernel(c))
    return DepthwiseConvDims{N, K, C_in, C_m, S, P, D, F}(I)
end

# This one is basically the same as for DenseConvDims, we only change a few lines for kernel channel count
function check_dims(x::NTuple{M}, w::NTuple{M}, y::NTuple{M}, cdims::DepthwiseConvDims) where {M}
    # First, check that channel counts are all correct:
    @assert x[M-1] == channels_in(cdims) DimensionMismatch("Data input channel count ($(x[M-1]) vs. $(channels_in(cdims)))")
    @assert y[M-1] == channels_out(cdims) DimensionMismatch("Data output channel count ($(y[M-1]) vs. $(channels_out(cdims)))")
    @assert w[M-1] == channel_multiplier(cdims) DimensionMismatch("Kernel multiplier channel count ($(w[M-1]) vs. $(channel_multiplier(cdims))")
    @assert w[M] == channels_in(cdims) DimensionMismatch("Kernel input channel count ($(w[M]) vs. $(channels_in(cdims)))")
    
    # Next, check that the spatial dimensions match up
    @assert x[1:M-2] == input_size(cdims) DimensionMismatch("Data input spatial size ($(x[1:M-2]) vs. $(input_size(cdims)))")
    @assert y[1:M-2] == output_size(cdims) DimensionMismatch("Data output spatial size ($(y[1:M-2]) vs. $(output_size(cdims)))")
    @assert w[1:M-2] == kernel_size(cdims) DimensionMismatch("Kernel spatial size ($(w[1:M-2]) vs. $(kernel_size(cdims)))")

    # Finally, check that the batch size matches
    @assert x[M] == y[M] DimensionMismatch("Batch size ($(x[M]) vs. $(y[M]))")
end