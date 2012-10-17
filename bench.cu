// #include <thrust/sort.h>
#include <thrust/reduce.h>
// #include <thrust/inner_product.h>
// #include <thrust/iterator/zip_iterator.h>
#include <thrust/sequence.h>
#include <thrust/tuple.h>
#include <thrust/generate.h>
#include <thrust/host_vector.h>
#include <thrust/device_vector.h>
#include <thrust/functional.h>
#include <thrust/transform_reduce.h>

#include <iostream>
// #include <algorithm>
#include <vector>
// #include <tuple>
#include <numeric>
// #include <backward/algo.h>
// #include <boost/timer.hpp>

#include "TH2D.h"
#include "TMatrixD.h"
#include "TROOT.h"
#include "TApplication.h"
#include "TCanvas.h"
#include "TStopwatch.h"
#include "TGraphErrors.h"
#include "TMultiGraph.h"
#include "TLegend.h"
#include "TMath.h"

namespace my {
	template <class ForwardIterator>
	void sequence (ForwardIterator first, ForwardIterator last) {
		int value = 0;
		for (; first != last; ++first) {
			*first = value;
			++value;
		}
	}
	
	template <typename T>
	struct square
	{
		__host__ __device__
		T operator()(const T& x) const { 
			return x * x;
		}
	};
}

int main(int argc, char** argv) {
	int upperBorder = 100000;
	if (argc > 1) upperBorder = atof(argv[1]);
	
	double yOffset = 0; // Needed for log plots -- set to one and uncomment setlogy below
	int incrementNOfNumbersBy = 2; // Can also be changed to + in outer for loop
	int nOfRepetition = 100; // How many times should each data vector be calculated - a mean is taken from those nOfReptition values
	
	std::vector<thrust::tuple<int, double, double, double> > allTheTimes; // nOfNumbers, cpu, gpu_Transfer, gpu_Compute
	std::vector<thrust::tuple<int, double, double, double> > allTheErrors;
	
	for (int nOfNumbers = 10; nOfNumbers <= upperBorder; nOfNumbers = nOfNumbers*incrementNOfNumbersBy) {
		std::vector<double> preAverageTime_cpu;
		std::vector<double> preAverageTime_gpuCopy;
		std::vector<double> preAverageTime_gpuCompute;
		
		thrust::host_vector<int> h_vec(nOfNumbers+1);
		
		// Stuff for timing on GPU
		cudaEvent_t start, intermediate, stop;
		cudaEventCreate(&start);
		cudaEventCreate(&intermediate);
		cudaEventCreate(&stop);
		float timeForCopy, timeForComputation;
		
		// Stuff for timing on CPU
		TStopwatch cpuWatch;
		
		
		srand(time(NULL));
		for (int i = 0; i < nOfRepetition; i++) {
			thrust::generate(h_vec.begin(), h_vec.end(), rand); // HOST
			
			// GPU
			cudaThreadSynchronize(); // make sure everything is ready
			
			cudaEventRecord(start, 0); // start recording on device
			
			thrust::device_vector<int> d_vec = h_vec; // copy stuff onto device
			
			cudaEventRecord(intermediate, 0); // make data point after copy
			
			int d_sumOfSquares = thrust::transform_reduce(d_vec.begin(), d_vec.end(), my::square<int>(), 0, thrust::plus<int>()); // reduce all squared values
			
			cudaThreadSynchronize(); // wait for all threads
			
			cudaEventRecord(stop, 0); // stop all counters
			cudaEventSynchronize(stop); // wait for stop to finish
			
			cudaEventElapsedTime(&timeForCopy, start, intermediate); // time for copy
			cudaEventElapsedTime(&timeForComputation, intermediate, stop); // time for computation
			
			
			
			// CPU
			cpuWatch.Start(true); // alternative: "boost::timer myTimer;"
			
			int h_sumOfSquares = thrust::transform_reduce(h_vec.begin(), h_vec.end(), my::square<int>(), 0, thrust::plus<int>()); // runs on host vectors
			
			cpuWatch.Stop();
			
			
			// Fill values
			preAverageTime_cpu.push_back(cpuWatch.CpuTime());
			preAverageTime_gpuCopy.push_back(timeForCopy);
			preAverageTime_gpuCompute.push_back(timeForComputation);
		}
		// Clean up:
		cudaEventDestroy(start);
		cudaEventDestroy(intermediate);
		cudaEventDestroy(stop);
		
		double meanCpu = TMath::Mean(preAverageTime_cpu.size(), &preAverageTime_cpu[0]); // the constructor of Mean using iterators "Mean(bla.begin(), bla.end())" doesn't seem to work
		double meanGpuCopy = TMath::Mean(preAverageTime_gpuCopy.size(), &preAverageTime_gpuCopy[0]);
		double meanGpuCompute = TMath::Mean(preAverageTime_gpuCompute.size(), &preAverageTime_gpuCompute[0]);
		double rmsCpu = TMath::RMS(preAverageTime_cpu.size(), &preAverageTime_cpu[0]);
		double rmsGpuCopy = TMath::RMS(preAverageTime_gpuCopy.size(), &preAverageTime_gpuCopy[0]);
		double rmsGpuCompute = TMath::RMS(preAverageTime_gpuCompute.size(), &preAverageTime_gpuCompute[0]);
		
		allTheTimes.push_back(thrust::make_tuple(nOfNumbers, meanCpu + yOffset, yOffset + meanGpuCopy/1000, yOffset + meanGpuCompute/1000));
		allTheErrors.push_back(thrust::make_tuple(nOfNumbers, rmsCpu + yOffset, yOffset + rmsGpuCopy/1000, yOffset + rmsGpuCompute/1000));
		
		
		std::cout << "Mean Time for " << nOfNumbers << " random numbers * " << nOfRepetition << std::endl;
		std::cout << "  CPU = " << meanCpu << "+-" << rmsCpu << "s" << std::endl;
		std::cout << "  GPU (Copy To) = " << meanGpuCopy/1000 << "+-" << rmsGpuCopy/1000 << "s" << std::endl;
		std::cout << "  GPU (Compute on) = " << meanGpuCompute/1000 << "+-" << rmsGpuCompute/1000 << "s" << std::endl;
	}
	
	TGraphErrors * graphCpu = new TGraphErrors();
	TGraphErrors * graphGpuCopy = new TGraphErrors();
	TGraphErrors * graphGpuCompute = new TGraphErrors();

	for (int i = 0; i < allTheTimes.size(); i++) {
		int nDataPoints = thrust::get<0>(allTheTimes[i]);
		graphCpu->SetPoint(i, nDataPoints, thrust::get<1>(allTheTimes[i]));
		graphGpuCopy->SetPoint(i, nDataPoints, thrust::get<2>(allTheTimes[i]));
		graphGpuCompute->SetPoint(i, nDataPoints, thrust::get<3>(allTheTimes[i]));

		graphCpu->SetPointError(i, 0, thrust::get<1>(allTheErrors[i]));
		graphGpuCopy->SetPointError(i, 0, thrust::get<2>(allTheErrors[i]));
		graphGpuCompute->SetPointError(i, 0, thrust::get<3>(allTheErrors[i]));
	}
	
// 	graphCpu->Print();
// 	graphGpuCompute->Print();
// 	graphGpuCopy->Print(); 
	
	int dotSize = 1;
	graphCpu->SetLineColor(kRed);
	graphCpu->SetFillColor(graphCpu->GetLineColor() - 10);
	graphCpu->SetMarkerStyle(kFullDotLarge);
	graphCpu->SetMarkerSize(dotSize);
	graphCpu->SetMarkerColor(graphCpu->GetLineColor() + 2);
	graphCpu->SetTitle("CPU");
	graphGpuCopy->SetLineColor(kBlue);
	graphGpuCopy->SetFillColor(graphGpuCopy->GetLineColor() - 10);
	graphGpuCopy->SetTitle("GPU - Copy");
	graphGpuCopy->SetMarkerStyle(kFullDotLarge);
	graphGpuCopy->SetMarkerSize(dotSize);
	graphGpuCopy->SetMarkerColor(graphGpuCopy->GetLineColor() + 2);
	graphGpuCompute->SetLineColor(kGreen+2);
	graphGpuCompute->SetFillColor(graphGpuCompute->GetLineColor() - 10);
	graphGpuCompute->SetTitle("GPU - Compute");
	graphGpuCompute->SetMarkerStyle(kFullDotLarge);
	graphGpuCompute->SetMarkerSize(dotSize);
	graphGpuCompute->SetMarkerColor(graphGpuCompute->GetLineColor() + 2);
	
	TApplication *theApp = new TApplication("app", &argc, argv, 0, -1);
	TCanvas * c1 = new TCanvas("c1", "default", 100, 10, 800, 600);
	
	TMultiGraph mg;

	mg.Add(graphCpu);
	mg.Add(graphGpuCopy);
	mg.Add(graphGpuCompute);
	
	mg.Draw("APL");
	mg.GetXaxis()->SetTitle("Random Numbers/#");
	mg.GetYaxis()->SetTitle("Time/s");
	
// 	gPad->SetLogy();
	
	TLegend * leg = c1->BuildLegend(0.1,0.75,0.42,0.9);
	leg->SetFillColor(kWhite);
	graphCpu->Fit("pol1","FQ");
	c1->Update();
	theApp->Run();

}