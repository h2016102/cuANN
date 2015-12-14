#include "kernel.hpp"
namespace cuANN
{

__global__ void forward_prop ( 
                               const float * weight, // W[ji] 
                               const float * input,  // O[j]
                               float * output,       // I[i]
                               unsigned int w_size   // weights per node (# of columns)
                             )
{
    // X is input size (w_size)
    int x = blockIdx.x * blockDim.x + threadIdx.x; 
    // Y is weights per neuron/node (i_size)
    int y = blockIdx.y * blockDim.y + threadIdx.y;   
    //  I[j] * W[i] - Row-Major Matrix
    output[w_size*x+y] = input[x] * weight[w_size * x + y];
}

__global__ void sum_columns ( 
                                float * w_mtx,
                                float * output, 
                                unsigned int height,
                                unsigned int width
                            )
{
    // X thread iterates Columns and sums their Row values
    int x = blockIdx.x * blockDim.x + threadIdx.x; 
    float total;
    for ( int y = 0; y < height; y++ )
    {
        total = total + w_mtx[y*width+x];
    }
    output[x] = total;
}

__global__ void delta_output (
                                const float * primed_sum,
                                const float * ideal,
                                const float * actual,
                                float * delta,
                                unsigned int index
                             )
{
    // x is the output neuron/node count (e.g., length of actual & ideal)
    int x = blockIdx.x * blockDim.x + threadIdx.x;
    // -E * σ'(Σ(O[i])
    delta[x+index] = -(actual[x] - ideal[x]) * primed_sum[x+index];
}

__global__ void delta_product (
                                const float * w_ik,
                                const float * d_k,
                                float * output,
                                unsigned int width
                              )
{
    // X is layer[i] nodes (size_i)
    int x = blockIdx.x * blockDim.x + threadIdx.x;
    // Y is layer[k] nodes (size_k) == d_k == w_per_n
    int y = blockIdx.y * blockDim.y + threadIdx.y;
    //  W[ik] * δ[k] - Row-Major Matrix
    output[width*x+y] = w_ik[width*x+y] * d_k[y];
}

__global__ void delta_sum_rows (
                                float * w_ik_d,
                                float * delta_i,
                                unsigned int width
                               )
{
    // X thread iterates Rows and Sums the respective Column values
    int x = blockIdx.x * blockDim.x + threadIdx.x; 
    float total = 0.f;
    for ( int y = 0; y < width; y++ )
    {
        total = total + w_ik_d[x*width+y];
    }
    delta_i[x] = total;
}

__global__ void delta_hidden (
                               float * prime_ji,
                               float * delta_i
                             )
{
    int x = blockIdx.x * blockDim.x + threadIdx.x;
    // NOTE: delta_i ALREADY contains `Σ(w[ik] * δ[k])`
    // δ[i] = σ'( Σ[ji]) * Σ(w[ik] * δ[k])
    delta_i[x] = prime_ji[x] * delta_i[x];
}

__global__ void gradient_descent (
                                    float * d_k,
                                    float * o_i,
                                    float * g_ik,
                                    unsigned int size_d
                                 )
{
    // X = Node Delta Count (layer k)
    int x = blockIdx.x * blockDim.x + threadIdx.x;
    // Y = Node Output Count (layer i)
    int y = blockIdx.y * blockDim.y + threadIdx.y;
    // Row-Major Matrix
    g_ik[size_d*x+y] = d_k[x] * o_i[y];
}

__global__ void sum_gradients (
                                float * gradient,
                                float * new_value
                              ) 
{
    // X Grid iterates all gradient values 
    int x = blockIdx.x * blockDim.x + threadIdx.x;
    // A Simple summation
    gradient[x] = gradient[x] + new_value[x];
}

__global__ void back_prop (
                            float * weight,
                            float * gradient,
                            float * update,
                            float alpha,
                            float epsilon
                         )
{
    // X Grid iterates weight, gradient and update (all same size)    
    int x = blockIdx.x * blockDim.x + threadIdx.x;
    // Δw(t) = ε * ( ∂E / ∂W[i] ) + α * ( Δw(t-1) )
    float d_w = (epsilon * gradient[x]) + (alpha * update[x]);
    // Update weight: W[i] = W[i] + Δw(t)
    weight[x] = weight[x] + d_w;
    // Set `Δw(t-1) = Δw(t)`
    update[x] = d_w;
}

__global__ void squared_error ( 
                                const float * ideal,
                                const float * actual, 
                                float * errors
                            )
{
    int x = blockIdx.x * blockDim.x + threadIdx.x;
    float diff = ideal[x] - actual[x];
    errors[x] = diff * diff;
    //printf("ideal: %f, actual: %f, diff: %f E²: %f\n",ideal[x],actual[x],diff,errors[x]);
}

};
