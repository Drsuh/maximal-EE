%This Matlab script can be used to generate Figure 6 and Figure 7 in the article:
%
%Emil Bjornson, Luca Sanguinetti, Marios Kountouris, "Deploying Dense
%Networks for Maximal Energy Efficiency: Small Cells Meet Massive MIMO,"
%IEEE Journal on Selected Areas in Communications, to appear.
%
%Download article: http://arxiv.org/pdf/1505.01181.pdf
%
%This is version 1.0 (Last edited: 2016-01-04)
%
%License: This code is licensed under the GPLv2 license. If you in any way
%use this code for research that results in publications, please cite our
%original article listed above.
%
%Please note that the channels are generated randomly, thus the results
%will not be exactly the same as in the paper.

%Initialization
close all;
clear all;

%Load Monte-Carlo simulated realizations (these are generated by the script
%generateMonteCarlo.m)
load resultsMC.mat;


%%Simulation parameters

%Define the range of user densities and the number of points to compute
nbrOfDensities = 200;
UEDensityValues = logspace(0,5,nbrOfDensities);

%Select the value of log2(1+gamma) that should be considered
rateValues = 2;
gammaval = 2^rateValues - 1;

%Propagation parameters
alpha = 3.76; %Pathloss exponent
omegaSigma2 = 1e-7; %Propagation loss multiplied with sigma2 (1e13*1e-20)
tau = 400; %Length of coherence block (in symbols)

%Hardware characterization
eta = 0.39; %Power amplifier efficiency
epsilon = 0.05; %Level of hardware impairments

%Spectral resources
T = 1/(2e7); %Symbol time (based on 20 MHz)

%Energy parameters
A = 1.15e-9; %Power consumed by coding, decoding, and backhaul (in J/bit)
C0 = 10 * T; %Static energy consumption (10 W divided over the symbols)
C1 = 0.1 * T; %Circuit energy per active UE
D0 = 0.2 * T; %Circuit energy per active BS antenna
D1 = 1.56e-10; %Signal processing coefficient


%Maximal number of antennas and users considered in the simulation. These
%numbers need to selected carefully so that the maximal value is not at the
%edge of the considered region.
Mmax = 300;
Kmax = 40;


%Placeholders for storing of simulation results
EE_optimal = zeros(nbrOfDensities,1); %Optimized EE for different user densities (using theoretical formulas)
optimalParameters = zeros(nbrOfDensities,4); %Store optimal parameter values for each point using the theoretical formulas
EE_MISO = zeros(nbrOfDensities,1); %EE with M=10 and K=1 for different user densities
EE_MIMO = zeros(nbrOfDensities,1); %EE with M=91 and K=10 for different user densities


%Go through all user densities
for n = 1:nbrOfDensities
    
    %Display simulation progress
    disp(['Lambda ' num2str(n) '/' num2str(nbrOfDensities)]);
    
    %Prepare to store the best parameters for each (M,K)-value
    EEtmp = zeros(Mmax,Kmax);
    betatmp = zeros(Mmax,Kmax);
    rhotmp = zeros(Mmax,Kmax);
    
    %Go through range of K values
    for k = 1:Kmax
        
        %Compute the required lambda value
        lambda = UEDensityValues(n)/k;
        
        %Go through range of M values
        for m = 1:Mmax
            
            %Find the best SNR=rho/sigma2 value by line search (1e6 is selected
            %as maximal value since 1/SNR is negligible at this number).
            [X,EEvalue] = fminbnd(@(x) -EEcomputation(x,lambda,m,k,gammaval,alpha,omegaSigma2,eta,epsilon,tau,A,C0,C1,D0,D1),0,1e6);
            
            %Check if the problem was feasible
            if X>=0 && EEvalue<0
                
                %Compute the B1 and B2 from Eq. (18) and Eq. (19)
                B1 = (4*k/(alpha-2)^2 + (k+m*(1-epsilon^2))/(alpha-1) + 2*(k+1/X)/(alpha-2));
                B2 = (k+1/X + 2*k/(alpha-2))*(1+1/X) + (1-epsilon^2)*epsilon^2*m;
                
                %Compute beta using Eq. (17)
                beta = B1*gammaval / (m*(1-epsilon^2)^2-B2*gammaval);
                
                %If the first constraint in Eq. (21) is satisfied, then
                %the results are stored.
                if beta >= 1
                    EEtmp(m,k) = -EEvalue*1e6;
                    rhotmp(m,k) = X;
                    betatmp(m,k) = beta;
                end
                
            end
            
        end
        
    end
    
    %Find the M and K values that maximize the EE
    [EEmaxM,optM] = max(EEtmp,[],1);
    [EEmax,optK] = max(EEmaxM);
    
    %Store the maximal EE
    EE_optimal(n) = EEmax;
    
    %Store the parameter values (M, K, rho and beta) that achieved the
    %maximal EE
    optimalParameters(n,:) = [optM(optK) optK rhotmp(optM(optK),optK) betatmp(optM(optK),optK) ];
    
    %Extract the EEs for the two reference cases
    EE_MISO(n) = EEtmp(10,1);
    EE_MIMO(n) = EEtmp(91,10);
    
end



%Plot Figure 6 from the paper
figure(6);
hold on; box on;

plot(UEDensityValues,EE_optimal/1e6,'b','LineWidth',1);
plot(UEDensityValues,EE_MIMO/1e6,'r--','LineWidth',1);
plot(UEDensityValues,EE_MISO/1e6,'k-.','LineWidth',1);

set(gca,'XScale','log');

xlabel('UE density (\mu) [UE/km^2]');
ylabel('Energy efficiency [Mbit/Joule]');
ylim([0 12]);
legend('Optimized M and K','MIMO: M=91, K=10','SIMO: M=10, K=1','Location','SouthEast');


%Plot Figure 7 from the paper
figure(7);
hold on; box on;

plot(UEDensityValues,UEDensityValues./optimalParameters(:,2)','b','LineWidth',1);
plot(UEDensityValues,UEDensityValues/10,'r--','LineWidth',1);
plot(UEDensityValues,UEDensityValues,'k-.','LineWidth',1);

set(gca,'XScale','log');
set(gca,'YScale','log');

xlabel('UE density (\mu) [UE/km^2]');
ylabel('BS density (\lambda) [BS/km^2]');
legend('Optimized M and K','MIMO: M=91, K=10','SIMO: M=10, K=1','Location','SouthEast');
