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
#include "TPaveText.h"
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
	
	int incrementWithDifferentOperator(const int baseValue, const int valueToIncrementBy, const bool plus)  {
		if (true == plus) {
			return baseValue + valueToIncrementBy;
		} else {
			return baseValue * valueToIncrementBy;
		}
	}
}

int main(int argc, char** argv) {
	int upperBorder = 100000;
	if (argc > 1) {
		std::cout << "Command line parameter syntax:" << std::endl
		<< "  " << argv[0] << " maxNumbers incrementBy nOfRepetition plusOrTimes" << std::endl
		<< "    maxNumbers = (int) amount of points of data to which this program increments to (Default = 100000)" << std::endl
		<< "    incrementBy = (int) for incrementing, the number of data points is multiplied by or added to (see below) this value (Default = 2)" << std::endl
		<< "    nOfRepetition = (int) for statistics reason, the calculation on each data points is repeated according to this number (Default = 100)" << std::endl
		<< "    plusOrTimes = (bool wrt plus) should incrementBy used on the current data point as multiplication or addition? 1 = plus, 0 = times (Default = times (0))" << std::endl;
	}
	if (argc > 1) upperBorder = atof(argv[1]);
	
	double yOffset = 0; // Needed for log plots -- set to one and uncomment setlogy below
	int incrementNOfNumbersBy = 2; // Can also be changed to + in outer for loop
	if (argc > 2) incrementNOfNumbersBy = atoi(argv[2]);
	int nOfRepetition = 100; // How many times should each data vector be calculated - a mean is taken from those nOfReptition values
	if (argc > 3) nOfRepetition = atoi(argv[3]);
	bool operatorForIncrementation = false; // true = plus; false = times
	if (argc > 4) operatorForIncrementation = (bool) atoi(argv[4]);
	
	std::vector<thrust::tuple<int, double, double, double> > allTheTimes; // nOfNumbers, cpu, gpu_Transfer, gpu_Compute
	std::vector<thrust::tuple<int, double, double, double> > allTheErrors;
	
	for (int nOfNumbers = 10; nOfNumbers <= upperBorder; nOfNumbers = my::incrementWithDifferentOperator(nOfNumbers,incrementNOfNumbersBy,operatorForIncrementation)) {
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
			
			cudaEventElapsedTime(&timeForCopy, start, intermediate); // time for copy in milliseconds (see http://developer.download.nvidia.com/compute/cuda/4_2/rel/toolkit/docs/online/group__CUDART__EVENT_g14c387cc57ce2e328f6669854e6020a5.html) 
			cudaEventElapsedTime(&timeForComputation, intermediate, stop); // time for computation in milliseconds
			
			
			
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
		double rmsCpu = TMath::RMS(preAverageTime_cpu.size(), &preAverageTime_cpu[0]); // Note: RMS() is not root mean square but the standard deviation
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
	TGraphErrors * graphGpuWhole = new TGraphErrors();

	for (int i = 0; i < allTheTimes.size(); i++) {
		int nDataPoints = thrust::get<0>(allTheTimes[i]);
		graphCpu->SetPoint(i, nDataPoints, thrust::get<1>(allTheTimes[i]));
		graphGpuCopy->SetPoint(i, nDataPoints, thrust::get<2>(allTheTimes[i]));
		graphGpuCompute->SetPoint(i, nDataPoints, thrust::get<3>(allTheTimes[i]));
		graphGpuWhole->SetPoint(i, nDataPoints, thrust::get<2>(allTheTimes[i]) + thrust::get<3>(allTheTimes[i]));

		graphCpu->SetPointError(i, 0, thrust::get<1>(allTheErrors[i]));
		graphGpuCopy->SetPointError(i, 0, thrust::get<2>(allTheErrors[i]));
		graphGpuCompute->SetPointError(i, 0, thrust::get<3>(allTheErrors[i]));
		graphGpuWhole->SetPointError(i, 0, thrust::get<2>(allTheErrors[i]) + thrust::get<3>(allTheErrors[i]));
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
	graphGpuCopy->SetTitle("GPU (copy)");
	graphGpuCopy->SetMarkerStyle(kFullDotLarge);
	graphGpuCopy->SetMarkerSize(dotSize);
	graphGpuCopy->SetMarkerColor(graphGpuCopy->GetLineColor() + 2);
	graphGpuCompute->SetLineColor(kGreen+2);
	graphGpuCompute->SetFillColor(graphGpuCompute->GetLineColor() - 10);
	graphGpuCompute->SetTitle("GPU (compute)");
	graphGpuCompute->SetMarkerStyle(kFullDotLarge);
	graphGpuCompute->SetMarkerSize(dotSize);
	graphGpuCompute->SetMarkerColor(graphGpuCompute->GetLineColor() + 2);
	graphGpuWhole->SetLineColor(kMagenta - 5);
	graphGpuWhole->SetFillColor(graphGpuWhole->GetLineColor() - 5);
	graphGpuWhole->SetTitle("GPU (whole)");
	graphGpuWhole->SetMarkerStyle(kFullDotLarge);
	graphGpuWhole->SetMarkerSize(dotSize);
	graphGpuWhole->SetMarkerColor(graphGpuWhole->GetLineColor() +2);
	
	TApplication *theApp = new TApplication("app", &argc, argv, 0, -1);
	TCanvas * c1 = new TCanvas("c1", "default", 100, 10, 800, 600);
	
	TMultiGraph mg;

	mg.Add(graphCpu);
	mg.Add(graphGpuCopy);
	mg.Add(graphGpuCompute);
	mg.Add(graphGpuWhole);
	
	mg.Draw("AP");
	mg.GetXaxis()->SetTitle("# Numbers/#");
	mg.GetYaxis()->SetTitle("Time/s");
	
// 	gPad->SetLogy();
	
	TLegend * leg = c1->BuildLegend(0.1,0.75,0.35,0.9);
	leg->SetFillColor(kWhite);
	TPaveText * formulaLeg = new TPaveText(0.35,0.75,0.45,0.9,"blNDC");
	formulaLeg->AddText("#sum^{N}_{i} = x^{2}");
	formulaLeg->SetFillColor(kWhite);
	formulaLeg->SetBorderSize(1);
	formulaLeg->SetTextSize(formulaLeg->GetTextSize()*0.7);

	std::cout << "Text size: " << formulaLeg->GetTextSize() << std::endl;

	bool doFit = true;
	if (true == doFit) {
		graphCpu->Fit("pol1","FQ");
		graphCpu->GetFunction("pol1")->SetLineColor(graphCpu->GetLineColor());
		graphCpu->GetFunction("pol1")->SetLineWidth(1);
		graphGpuCompute->Fit("pol1", "FQ");
		graphGpuCompute->GetFunction("pol1")->SetLineColor(graphGpuCompute->GetLineColor());
		graphGpuCompute->GetFunction("pol1")->SetLineWidth(1);
		graphGpuCopy->Fit("pol1", "FQ");
		graphGpuCopy->GetFunction("pol1")->SetLineColor(graphGpuCopy->GetLineColor());
		graphGpuCopy->GetFunction("pol1")->SetLineWidth(1);
		graphGpuWhole->Fit("pol1","FQ");
		graphGpuWhole->GetFunction("pol1")->SetLineColor(graphGpuWhole->GetLineColor());
		graphGpuWhole->GetFunction("pol1")->SetLineWidth(1);
	}
// 	fCpu->Draw("SAME");
// 	fGpuCompute->Draw("SAME");
// 	fGpuCopy->Draw("SAME");
	formulaLeg->Draw();
	c1->Update();


	theApp->Run();
	std::cout << "After" << std::endl;

}