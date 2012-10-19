# CUDA Thrust Performance Test
Simple test to benchmark the performance of **CUDA Thrust** and a **CPU**.  
Reason: To show off some benefits of using a GPU at a presentation at our institute's meeting. Will probably share a link to my slides here later. Maybe.

To display results, CERN's [ROOT](http://root.cern.ch) library is used. Change your path in the `Makefile`.
## Call
Running `./bench` is equal to a call to

    ./bench 100000 2 100 0
which should be a good enough visualisation of the great power of GPUs.
Adding anything behind a plain `./bench` call will display the possible parameters.

## Strategy
* A number (10) of random numbers are generated and filled into a `thrust::host_vector`
* Through a simple `thrust::device_vector d_vec = h_vec` these random numbers are copyed onto the device
* A `thrust::transform_reduce` is called, squaring each element of a given vector by my own `my::square` operator and then `thrust::plus`ing all vector elements. This is done …
    1. on the **GPU** device, using `d_vec`
    2. on the **CPU**, using `h_vec`
* The last steps are repeated a number of times (100) to get some statistics
* The time, the GPU and the CPU needed for their computations, are averaged. The mean is saved.
* A new number of random numbers (100) are generated and filled into the `thrust::host_vector` …
* The procedure starts again and continues until a breakpoint (command line, default 100000 random numbers) is reached
* ROOT's `TGraph`s are created, styled and plotted

## Timed parameteres
Three things are measured:

1. The time, the **CPU** needs for a sum of squares
2. The time, the **GPU** needs for a sum of squares
3. The time, the data needs to be **copied** onto the GPU

For 1., a `TStopwatch` from ROOT is employed. I compared it's usage and resolution to some other methods (including `boost::timer`), but the `TStopwatch` seemed as (un)precise as the rest but more easily to handle. So I used this.  
For 2. and 3. I make use of `cudaEvent*` – more precise, of `cudaEventRecord`. Some more lines of code but, as I read, a good way of measuring real time on the device – and not the time other in-between stuff needs.

## To Do
The following things are to be done, or probably already done because I forgot to update this README.

* Display different areas of the plot in different `TCanvas`ses
    * First area: 1 - 50.000 / 5.000 (point of interesection)
    * Second area: Full area, to see how great GPUs are
    * Maybe make part of it into on out-of-main method?
    
    
## Thanks
All this stuff is loosly based on Wayne Wood's [computing performance article at codeproject](http://www.codeproject.com/Articles/83757/A-Brief-Test-on-the-Code-Efficiency-of-CUDA-and-Th), to which I turned after my first approach didn't show any difference in computing time.