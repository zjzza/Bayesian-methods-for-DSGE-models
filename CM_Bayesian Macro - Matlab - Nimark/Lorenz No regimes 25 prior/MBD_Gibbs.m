%--------------------------------------------------------------------------
% Gibbs sampling algorithm to estimate Man-Bites-Dog model
%
% Based on Chib Journal of Economtrics (1996)
%
%--------------------------------------------------------------------------

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Housekeeping
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
clear all;
clc;
format short;
warning off all;
restart=0;
startfrompreviousmax=0;
maxsurv=25;
[Z,CPImean,NGDPmean,NonZeroCPI,NonZeroNGDP]=CleanData(maxsurv);
T=length(Z);
ill=0;
maxct=[]; counthis=[];mhe=[];
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Set starting values for parameters
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Example: man bites dog
rho1=0.87; %persistence of technology
rho2=0.72; %persistence of demand
sigu=.018;  %s.d. of state innov
sigud=0.01; %s.d. "demand" shock
sigur=.014;  %s.d. of m.p. shock
sigaj=.25;  %s.d. of island tech
sigzj1=.4;  %s.d. of private info noise
sigzj2=.4;  %s.d. of private info noise
sigdj=0.21;  %s.d. of island demand
sigmbd=0.5; %s.d. of m-b-d signal
varphi=1.1; %labour supply curvature
delta=1.07; %elasticity of demand
fir=0.08;%Interest inertia
fipi=1.55; %Taylor param;
fiy=0.24; %Taylor rule param
stick=0.74; %Calvo parameter
beta=0.99; %discount rate
gamma=4.27;    %s.d. multiplier of u when S=1
omega=0.05;  %unconditional prob of S=1, i.e. of observing pub signal

theta=[rho1,rho2,sigu,sigud,sigur,sigaj,sigzj1,sigzj2,sigdj,sigmbd,varphi,delta,fir,fipi,fiy,stick,beta,gamma;]';

xmax=theta;
if startfrompreviousmax ==1;
    load('xmax');
    theta=xmax;
end
lastMCMC=[];

if restart==1;
    load('xmax');
    load('llmax');
    %     theta=xmax;
    load('lastMCMC');
    theta=lastMCMC(:,end-1);
    %     vscale=cov(lastMCMC');
    load('vscale');
else
    llmax = -9e+200;
end
%Define boundary of THETA
LB=[zeros(1,5),0,0,0,0,0,0,0,0,1.001,0,0,0.97,1;]';
UB=[0.9999,0.9999,ones(1,10)*5,1,3,2,1,1,10;]';
%-----------------------------------------------------------------
%Define hyper parameters etc
%-----------------------------------------------------------------
kbar=8;
tol=1e-4;
bindim=5;% Number of periods that matter (Markov order, if you like) and dimension of binary identifier of time varying matrices
binmax=2^(bindim); % Number of "regimes"
dimS=2;
for j=1:bindim;
    binbase(1,bindim-j+1)=2^(j-1);
end

jlag=zeros(binmax,1);
jlead1=zeros(binmax,1);
jlead0=zeros(binmax,1);
for j=1:binmax;
    zvec=dec2binvec((j-1),bindim);
    jlag(j)=binbase*[0 zvec(1,1:end-1) ]';
    jlead1(j)=binbase*[zvec(1,2:end) 1 ]';
    jlead0(j)=binbase*[zvec(1,2:end) 0 ]';
end


x=theta;



% ST=zeros(length(Z),1);
% ST([2:10,110:end])=1;
load('StartST');
ST=StartST';
% load('StartST2');
% ST=StartST2;
ST=[zeros(bindim,1);ST;];
STMCMC(:,1)=ST;



% load('lastMCMC');

% llmax=-MBDLL(xmax,zmax)
% llmax=-1e200;

if restart==1;
    STMCMC=[];
    load('STMCMC');
    ST=STMCMC(:,end-1);
end
%----------------------------------------------------------
%Get starting values for MOAF
%----------------------------------------------------------

% [Pst,pst,Mst,Nst,Kst,Dst,Lst,Rst,Rjst,RRjst,SigJst,DIFFTS,M0,N0,a0,b0,d0,ast,bst,dst,dimx,dimX,dimu,dimuj,e1,e2,H]= SVLorenz(theta,kbar,tol,binmax);

%--------------------------------------------------------------------------
% Set control parameters
%--------------------------------------------------------------------------


%Number of draws (the ones in the outer loop of the MH)
S=1e4;
%Number of draws (the ones in the inner loop of the MH)
s=1e2;
%Calibrates vcscale for the first iterinitial iterations of S using an
%identity matrix times epseye.
iterinitial=13;
epseye=1e-6;
%Values for the constants in the adaptive proposal.
sd=1e-6; %Governs the acceptance rate : AIM FOR approx 0.23 !!

eps=2e-6;
%Proportion of draws to be discarded for burnin purposes
burnin=0.5;
%Every how many iterations the program display the results
dispiter=100;
%Every how many iterations the program updates the scale matrix
calibiter=100;
%Every how many iterations the MCMC is saved
saveMCMC=1000;


fails=[];

%--------------------------------------------------------------------------
% Initializes the MH algorithm
%--------------------------------------------------------------------------

%Set up so that the first candidate draw is always accepted
if restart ==0
    lpostdraw = -9e+200;
    lpostcan = -9e+200;
    bdraw=x;
    mean0=x;
else
    
    bdraw=theta;
    [Pst,pst,Mst,Nst,Kst,Dst,Lst,Rst,Rjst,RRjst,SigJst,M0,N0,a0,b0,d0,ast,bst,dst,dimx,dimX,dimu,dimuj,e1,e2,H,EE]= SVLorenz(bdraw,kbar,tol,binmax);
    [P,p,M,K,N,L,D,R,Rj,RRj,a,b,d,SigJ,EE] = MOAFLorenz(Pst,pst,Mst,Kst,Dst,Nst,Lst,Rst,Rjst,RRjst,ast,bst,dst,e1,e2,H,tol,binmax,dimx,dimX,dimu,dimuj,jlag,jlead1,jlead0,SigJst,bdraw);
    lpostdraw= MBDLL(M,N,a,b,e1,bindim,dimX,jlead1,jlead0,SigJ,bdraw,Z,ST,T,CPImean,NGDPmean,NonZeroCPI,NonZeroNGDP,maxsurv,H);
    lpostcan = lpostdraw;
end



if restart==0;
    vscale=diag(abs(theta))*epseye;
    % vscale=diag(UB-LB)*epseye;
end
%Store all draws in the following matrices which are initialized here
bb_=zeros(length(x),s);
OutsideProp=zeros(S,1);
SwitchesProp=zeros(S,1);
%Number of draws outside parameter boundaries
q=0;
%Number of switches (acceptances)
pswitch=0;

%%
tic
% [P,p,M,N,K,D,L,R,Rj,RRj,SigJ,M0,N0,a0,b0,d0,a,b,d,dimx,dimX,dimu,dimuj,e1,e2,H,EE]= SVLorenz(theta,kbar,tol,binmax);
[Pst,pst,Mst,Nst,Kst,Dst,Lst,Rst,Rjst,RRjst,SigJst,M0,N0,a0,b0,d0,ast,bst,dst,dimx,dimX,dimu,dimuj,e1,e2,H,EE]= SVLorenz(theta,kbar,tol,binmax);
EE
toc
%%
%--------------------------------------------------------------------------
% MH algorithm starts here
%--------------------------------------------------------------------------

% Start of the outer MH loop.

for iter=1:S
    tic
    
    for iter2=1:s
        
        bcan = bdraw + norm_rnd(vscale);
       
        if min(bcan > LB)==1
            if min(bcan < UB)==1;
                [Pst,pst,Mst,Nst,Kst,Dst,Lst,Rst,Rjst,RRjst,SigJst,M0,N0,a0,b0,d0,ast,bst,dst,dimx,dimX,dimu,dimuj,e1,e2,H,EE]= SVLorenz(bcan,kbar,tol,binmax);
                if EE ==1;
                    [P,p,M,K,N,L,D,R,Rj,RRj,a,b,d,SigJ,EE] = MOAFLorenz(Pst,pst,Mst,Kst,Dst,Nst,Lst,Rst,Rjst,RRjst,ast,bst,dst,e1,e2,H,tol,binmax,dimx,dimX,dimu,dimuj,jlag,jlead1,jlead0,SigJst,bcan);
                end
                %                lpostcan = MBDpriorLL(bcan)+MBDLL(M,N,a,b,e1,bindim,dimX,jlead1,jlead0,SigJ,theta,Z,ST,T,CPImean,NGDPmean,NonZeroCPI,NonZeroNGDP);
                if EE==1;
                    lpostcan = MBDLL(M,N,a,b,e1,bindim,dimX,jlead1,jlead0,SigJ,bcan,Z,ST,T,CPImean,NGDPmean,NonZeroCPI,NonZeroNGDP,maxsurv,H);
                    laccprob = lpostcan-lpostdraw + log(binom_dist(T,bcan(18),sum(ST==1))) - log(binom_dist(T,bdraw(18),sum(ST==1)));
                else
                    laccprob= -9e+200;
                end
            else
                counthis=[counthis 0];
                laccprob=-9e+200;
                q=q+1;
            end
        else
            laccprob=-9e+200;
            q=q+1;
        end
        if lpostcan >= llmax;
            llmax=lpostcan;
            xmax=bcan;
        end
        %Accept candidate draw with log prob = laccprob, else keep old draw
        if log(rand)<laccprob
            lpostdraw=lpostcan;
            bdraw=bcan;
            pswitch=pswitch+1;
            Pst=P;pst=p;Mst=M;Kst=K;Dst=D;Nst=N;Lst=L;Rst=R;Rjst=Rj;RRjst=RRj;ast=a;bst=b;dst=d;SigJst=SigJ;
            
        end
        
        bb_(:,iter2)=bdraw;
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % construct posterior for ST
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        
        for t=1:T
            %         t=ceil(rand*(T+bindim));
            
            STcan=ST;
            %         if log(rand) <= log(bdraw(18))
            if log(rand) <= log(0.05)
                STcan(t)=1;
            else
                STcan(t)=0;
            end
            
            llSTcan=MBDLL(Mst,Nst,ast,bst,e1,bindim,dimX,jlead1,jlead0,SigJst,bdraw,Z,STcan,T,CPImean,NGDPmean,NonZeroCPI,NonZeroNGDP,maxsurv,H);
            
            if (isnan(llSTcan))==0
                
                laccprobST = llSTcan-lpostdraw + log(binom_dist(T,bdraw(18),sum(STcan==1))) - log(binom_dist(T,bdraw(18),sum(ST==1)));
                
                
                
                if llSTcan >= llmax;
                    llmax=llSTcan;
                    xmax=bdraw;
                    STmax=STcan;
                end
                %Accept candidate draw with log prob = laccprob, else keep old draw
                if log(rand)<laccprobST
                    ST=STcan;
                    lpostdraw=llSTcan;
                end
            end
            
        end
        
        
        
        
    end
    disp('%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%');
    toc
    
    disp('acceptance rate and fraction outside bounds');
    [pswitch/(iter*s) q/(iter*s)]
    
    STMCMC=[STMCMC ST];
    lastMCMC=[lastMCMC bb_(:,iter2);];
    
    %     if length(lastMCMC(1,:)) >= (length(x)+1);
    if length(lastMCMC(1,:)) >= 40;
        SIGMCMC=cov(lastMCMC(:,20:end)');
        %         vscale=sd*SIGMCMC;
        if length(lastMCMC(1,:)) >= (length(x)+101);
            SIGold=cov(lastMCMC(:,1:end-100)');
            oldMCMC=lastMCMC(:,1:end-100);
        else
            SIGold=SIGMCMC;
            oldMCMC=lastMCMC;
        end
        disp('Current, mode, mean, change in mean last 10 000 draws, s.d., change in s.d. of MCMC last 10 000 draws');
        [bdraw, xmax, mean(lastMCMC')', (mean(lastMCMC')'-mean(oldMCMC')'), diag(SIGMCMC).^.5, (diag(SIGMCMC).^.5)-(diag(SIGold).^.5);]
        disp('Current likelihood and at mode');[lpostdraw llmax]
    else
        disp('Current mode');xmax
        disp('Likelihood at mode');llmax
        
    end
    disp('Total number of draws');length(lastMCMC(1,:))*s
    
    
    %         end
    save('STMCMC','STMCMC')
    save('lastMCMC','lastMCMC');
    save('xmax','xmax');
    save('llmax','llmax');
    save('vscale','vscale');
end


% %--------------------------------------------------------------------------
% % Plots the posteriors
% %--------------------------------------------------------------------------
%
% plotpost(lastMCMC,0);
% plotpost(lastMCMC(:,end-6500:end),1);
% YYY=convcheck(lastMCMC(:,end-6500:end));
