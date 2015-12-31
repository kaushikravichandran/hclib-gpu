#include <iostream>
#include <assert.h>
#include <cuda_runtime_api.h>

#include "hclib_cpp.h"

#define CHECK_CUDA(call) { \
    const cudaError_t err = (call); \
    if (err != cudaSuccess) { \
        fprintf(stderr, "CUDA ERROR @ %s:%d - %s\n", __FILE__, __LINE__, \
                cudaGetErrorString(err)); \
        exit(1); \
    } \
}

class test_functor {
    private:
        int *arr;
    public:
        test_functor(int *set_arr) : arr(set_arr) { }

        __host__ __device__ void operator()(int idx) {
            arr[idx] = idx;
        }
};

void validate(int *arr, int N) {
    for (int i = 0; i < N; i++) {
        if (arr[i] != i) {
            fprintf(stderr, "Error validating element %d. Expected %d but got "
                    "%d\n", i, i, arr[i]);
            exit(1);
        }
    }
}

int main(int argc, char **argv) {

    hclib::launch(&argc, argv, []() {
        hclib::place_t *root_pl = hclib::get_root_place();

        int num_toplevel;
        hclib::place_t **toplevel = hclib::get_children_of_place(root_pl,
                &num_toplevel);
        hclib::place_t *gpu_place = NULL;
        hclib::place_t *cpu_place = NULL;
        for (int i = 0; i < num_toplevel && (cpu_place == NULL ||
                    gpu_place == NULL); i++) {
            if (toplevel[i]->type == NVGPU_PLACE) {
                gpu_place = toplevel[i];
            } else {
                cpu_place = toplevel[i];
            }
        }
        assert(gpu_place && cpu_place);

        const int N = 1024;

        /******* Test on the CPU *******/
        int *arr = hclib::allocate_at<int>(cpu_place, N, 0);
        assert(arr);

        hclib_promise_t *cpu_memset_event = hclib::async_memset(cpu_place, arr, 0,
                N, NULL, arr);

        hclib::promise_t **cpu_kernel_deps = (hclib::promise_t **)malloc(2 * sizeof(hclib::promise_t *));
        cpu_kernel_deps[0] = cpu_memset_event; cpu_kernel_deps[1] = NULL;
        loop_domain_t loop = {0, N, 1, 33};
        test_functor cpu_kernel(arr);
        hclib::promise_t *cpu_kernel_event = hclib::forasync1D_future(
                (loop_domain_t *)&loop, cpu_kernel, FORASYNC_MODE_FLAT, cpu_place, cpu_kernel_deps);

        hclib::promise_wait(cpu_kernel_event);

        validate(arr, N);

        /******* Test on the GPU using functors *******/
        int *d_arr = hclib::allocate_at<int>(gpu_place, N, 0);
        assert(d_arr);

        hclib::promise_t *gpu_memset_event = hclib::async_memset(gpu_place, d_arr,
                0, N, NULL, d_arr);

        hclib::promise_t **gpu_kernel_deps = (hclib::promise_t **)malloc(
                2 * sizeof(hclib::promise_t *));
        gpu_kernel_deps[0] = gpu_memset_event; gpu_kernel_deps[1] = NULL;
        test_functor gpu_kernel(d_arr);
        hclib::promise_t *gpu_kernel_event = hclib::forasync1D_future(
                (loop_domain_t *)&loop, gpu_kernel, FORASYNC_MODE_FLAT,
                gpu_place, gpu_kernel_deps);

        hclib::promise_t **gpu_copy_deps = (hclib::promise_t **)malloc(
                2 * sizeof(hclib::promise_t *));
        gpu_copy_deps[0] = gpu_kernel_event; gpu_copy_deps[1] = NULL;
        hclib::promise_t *copy_event = hclib::async_copy(cpu_place, arr, gpu_place,
                d_arr, N, gpu_copy_deps, arr);
        hclib::promise_wait(copy_event);

        validate(arr, N);

        printf("Passed!\n");
    });
    return 0;
}