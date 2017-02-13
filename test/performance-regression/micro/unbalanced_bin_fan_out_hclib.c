#include "hclib.h"

#include <stdio.h>
#include "unbalanced_bin_fan_out.h"

/*
 * Calculate micro-statistics:
 *
 *   1) Rate at which we can spawn empty tasks.
 *   2) Rate at which we can schedule and execute empty tasks.
 */

void recurse(void *arg) {
    const int depth = ((size_t)arg) & 0xffffffff;
    const int branch = ((size_t)arg) >> 32;
    const int depth_limit = branch * BIN_FAN_OUT_DEPTH_MULTIPLIER;

    if (depth < depth_limit) {
        size_t next = branch;
        next = next << 32;
        next = next | depth;

        hclib_async(recurse, (void *)next, NULL, 0, NULL);
        hclib_async(recurse, (void *)next, NULL, 0, NULL);
    }
}

void entrypoint(void *arg) {
    int nworkers = hclib_num_workers();

    printf("Using %d HClib workers\n", nworkers);

    const unsigned long long start_time = hclib_current_time_ns();
    hclib_start_finish();
    {
        int i;
        for (i = 0; i < N_BRANCHES; i++) {
            size_t next = i;
            next = next << 32;
            next = next | (int)0;

            recurse((void *)next);
        }
    }
    hclib_end_finish();
    const unsigned long long end_time = hclib_current_time_ns();
    printf("HClib did unbalanced binary fan out w/ %d branches and depth "
            "multiplier %d in %llu ns\n", N_BRANCHES,
            BIN_FAN_OUT_DEPTH_MULTIPLIER, end_time - start_time);
}

int main(int argc, char **argv) {
    int i;

    hclib_launch(entrypoint, NULL, NULL, 0);
}