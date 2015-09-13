function [M,ufkst,states,PAI]=stochastic_impact_cumulator(model,y0,nsteps,y_pos,e_pos,states)
% cumulated_impacts -- creates impact matrix for contemporaneous and future
% shocks
%
% Syntax
% -------
% ::
%
%   [M,ufkst,states]=stochastic_impact_cumulator(model,y0,nsteps,y_pos,e_pos,states)
%
% Inputs
% -------
%
% - **T** [{}]:
%
% - **sstate** [{}]:
%
% - **y0** [{}]:
%
% - **states** [{}]:
%
% - **state_cols** [{}]:
%
% - **k** [{}]:
%
% - **Qfunc** [{}]:
%
% - **nsteps** [{}]:
%
% - **y_pos** [{}]:
%
% - **e_pos** [{}]:
%
% Outputs
% --------
%
% - **M** [{}]:
%
% - **ufkst** [{}]:
%
% More About
% ------------
%
% Examples
% ---------
%
% See also:

% - Here we don't need to know anything about how long we have data for.
% After building the matrix, we can use the hypotheses to chop off the
% extra columns
% - admissibility, then, will reflect the fact that the maximum horizon of
% shocks may be constrained by the availability of the data, depending on
% the hypothesis entertained.
% - It will also be possible to kill the non-active shocks although,
% perhaps, that could already be baked into the solution...
% - the steady state can no longer be dealt with only at the end because it
% may change from one state to another
% - What is the most likely combination of shocks (and states) that
% minimizes some variance... This could be an optimization problem...
% whereby we optimize over both states and shocks. But then, the problem
% does not have to be linear or conditionally linear. This is a more
% general problem in the sense that we can even add restrictions such as
% zlb and so on.
% - entropy forecasting

% FileInfo = dir('bvar_rise.m')
% http://www.mathworks.com/matlabcentral/answers/33220-how-do-i-get-the-file-date-and-time
% fs2000sims.mat
% altmany at gmail.com

if nargin<6
    states=[];
    if nargin<5
        e_pos=[];
        if nargin<4
            y_pos=[];
        end
    end
end

% is_stochastic=isempty(states)||any(isnan(states));
if isempty(states)
    states=nan(nsteps,1);
end
if numel(states)~=nsteps
    error('number of states does not match number of steps')
end

T=model.T;
sstate=model.sstate;
state_cols=model.state_cols;
k=model.k;
Qfunc=model.Qfunc;

[ny,nz]=size(T{1});
h=size(T,2);
nx=numel(state_cols);
nshocks=(nz-(nx+1))/(k+1);
[C,Ty,Te]=separate_terms();
% const/y{-1}/shk(0)/shk(1)/.../shk(k)/shk(k+1)/.../shk(k+nsteps-1)
ProtoR=cell(1,1+1+k+nsteps);
ProtoR{1}=zeros(ny,1);
ProtoR{2}=y0;
ncols=1+1+(k+nsteps)*nshocks;
nconds=numel(y_pos);
R=zeros(nconds*nsteps,ncols);
ufkst=y0(:,ones(1,nsteps+1));
PAI=zeros(h,nsteps+1);
for jstep=1:nsteps
    % pick the state
    %----------------
    st=pick_a_regime();
    % deal with the constant
    %------------------------
    ProtoR{1}=C{st}+Ty{st}*ProtoR{1};
    % origin
    %--------
    ProtoR{2}=Ty{st}*ProtoR{2};
    % shocks
    %--------
    iter=2;
    for icol=1:k+jstep
        iter=iter+1;
        if isempty(ProtoR{iter});
            ProtoR{iter}=zeros(ny,nshocks);
        else
            ProtoR{iter}=Ty{st}*ProtoR{iter};
        end
        which_shock=icol-jstep+1;
        if which_shock>0
            ProtoR{iter}=ProtoR{iter}+Te{st}{which_shock};
        end
    end
    % process all cells up to iter
    %------------------------------
    tmp=cell2mat(ProtoR(:,1:iter));
    R((jstep-1)*nconds+1:jstep*nconds,1:size(tmp,2))=tmp(y_pos,:);
    ufkst(:,jstep+1)=tmp(:,2); % unconditional forecasts
    
    % next period's origin
    %----------------------
    y0=ProtoR{1}+ProtoR{2};
end

% create rows for the shocks
%---------------------------------
S=do_shocks_conditions();

% format output
%---------------
R=sparse(R);
M=struct('R',R(:,3:end),'ufkst',R(:,2),'const',R(:,1),'S',S,...
    'nshocks',nshocks,'ny',ny);

    function reg=pick_a_regime()
        if isnan(states(jstep))
            if h==1
                states(jstep)=1;
                PAI(:,jstep)=1;
            else
                Q=Qfunc(y0);
                if jstep==1
                    [PAI0,retcode]=initial_markov_distribution(Q,true);
                    if retcode
                        warning('ergodic distribution failed...')
                        PAI0=initial_markov_distribution(Q,false);
                    end
                    PAI(:,jstep)=PAI0(:);
                else
                    % draw conditional on yesterday's state
                    PAI(:,jstep)=Q(states(jstep-1),:).';
                end
                cp=cumsum(PAI(:,jstep).');
                cp=[0,cp];
                states(jstep)=find(cp>rand,1,'first')-1;
            end
        end
        reg=states(jstep);
    end

    function [C,Ty,Te]=separate_terms()
        C=cell(1,h);
        Ty=cell(1,h);
        Te=cell(1,h);
        Iy=eye(ny);
        dim1Dist=ny;
        dim2Dist=nshocks*ones(1,k+1);
        for ireg=1:h
            Ti=T{ireg};
            Tx=Ti(:,1:nx);
            Ty{ireg}=add_zeros(Tx);
            Tsig=Ti(:,nx+1);
            Te{ireg}=mat2cell(Ti(:,nx+2:end),dim1Dist,dim2Dist);
            C{ireg}=(Iy-Ty{ireg})*sstate{ireg}+Tsig;
        end
        function Ty=add_zeros(Tx)
            Ty=zeros(ny);
            Ty(:,state_cols)=Tx;
        end
    end

    function S=do_shocks_conditions()
        S=speye(nshocks*(k+nsteps));
        e_good=false(nshocks,1);
        e_good(e_pos)=true;
        e_good=e_good(:,ones(1,k+nsteps));
        S=S(e_good(:),:);
    end
end