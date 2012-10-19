## Examples for CUDA Thrust CPU Benchmarking Tool
Some example plots using this tool.

If you haven't looked into the source code, here a crash course:

* take a vector of n random elements, n being 10, 20, 30 (see the vector.size() range part)
* square each element and sum up all elements of the vector
* measure computing time for that on
    * the CPU
    * the GPU
* plot a graph for the times needed

The colors used are as follows:

* red = CPU time
* blue = GPU computation time (time needed for the actual computation on the device)
* green = GPU copy time (time needed to copy the stuff onto the device)
* magenta = a sum of all GPU times


#### [**1-smallRange.pdf**](1-smallRange.pdf)
<img src="https://raw.github.com/AndiH/CUDA-bench/master/examples/thumbs/1-smallRange.png" width=150px style="float: left; margin: 3px"/>You see CPU times slowly rising beyond GPU threshold, even over the combined GPU Copy+Compute value. There's a jump at around ~300 vector.size() which I actually can't explain (can you?). No errors in this picture, too messy.  
vector.size() range: 0 - 5000.  
Call: `./bench 5000 100 100 1`


#### [2-midRange-highGranularity](2-midRange-highGranularity.pdf)
<img src="https://raw.github.com/AndiH/CUDA-bench/master/examples/thumbs/2-midRange-highGranularity.png" width=150px style="float: left; margin: 3px"/>Now for sure you see, that the CPU climbs the mountain of computation time while the GPU stays at the valley.  
vector.size() range: 0 - 200,000.

#### [3-largeRange-lowGranularity](3-largeRange-lowGranularity.pdf)
<img src="https://raw.github.com/AndiH/CUDA-bench/master/examples/thumbs/3-largeRange-lowGranularity.png" width=150px style="float: left; margin: 3px"/>With errors but just a few points to get an impression.  
vector.size() range: 0 - 1,000,000

#### [4-largeRange-highGranularity](4-largeRange-highGranularity.pdf)
<img src="https://raw.github.com/AndiH/CUDA-bench/master/examples/thumbs/4-largeRange-highGranularity.png" width=150px style="float:left; margin: 3px"/>Maybe the most interesting plot in this set.  
Like the previous graph, but this time more points per unit. Errors are shown for the cpu graph (but only for a small 10 statistics).
vector.size() range: 0 - 1,000,000

#### [5-largeRange-highGranularity-GPUZoom](5-largeRange-highGranularity-GPUZoom.pdf)
<img src="https://raw.github.com/AndiH/CUDA-bench/master/examples/thumbs/5-largeRange-highGranularity-GPUZoom.png" width=150px style="float: left; margin: 3px"/>
Because in the previous picture the gpu graphs are buried below cpu trash, here's a zoom on the gpu parts.  
You see that while the gpu computing time stays equal (actually it doesn't, but the change is so little) the real time consuming fact is the copy onto the gpu.  
vector.size() range: 0 - 1,000,000

#### [6-hugeRange-speedup100x](6-hugeRange-speedup100x.pdf)
<img src="https://raw.github.com/AndiH/CUDA-bench/master/examples/thumbs/6-hugeRange-speedup100x.png" width=150px style="float: left; margin: 3px"/>One plot to show off. Because, believe it or not, here's a **speedup of 102x** displayed. Yay, GPU!  
vector.size() range: 0 - 9,000,000
