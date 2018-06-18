function [modelIrrev,matchRev,rev2irrev,irrev2rev] = ncomm_blais_model2irrev(model)
%ncomm_blais_model2irrev Convert model to irreversible format. 
% ncomm_blais_model2irrev is modified version of convertToIrreversible 
% from the COBRA toolbox (www.github.com/opencobra/cobratoolbox) 
% that facilitates the mapping of TIMBR reaction weights to irreversible reactions
%
% [modelIrrev,matchRev,rev2irrev,irrev2rev] = ncomm_blais_model2irrev(model)
%
%INPUT
% model         COBRA model structure
%
%OUTPUTS
% modelIrrev    Model in irreversible format
% matchRev      Matching of forward and backward reactions of a reversible
%               reaction
% rev2irrev     Matching from reversible to irreversible reactions
% irrev2rev     Matching from irreversible to reversible reactions
%
% Uses the reversible list to construct a new model with reversible
% reactions separated into forward and backward reactions.  Separated
% reactions are appended with '_f' and '_r' and the reversible list tracks
% these changes with a '1' corresponding to separated forward reactions.
% Reactions entirely in the negative direction will be reversed and
% appended with '_r'.
%
% written by Gregory Hannum 7/9/05
%
% Modified by Markus Herrgard 7/25/05
% Modified by Jan Schellenberger 9/9/09 for speed.
% Modified by Edik Blais 2/01/16 for implementing TIMBR 
% with rat and human metabolic networks (www.github.com/edikblais/ratcon)

%declare variables
modelIrrev.S = spalloc(size(model.S,1),0,2*nnz(model.S));
modelIrrev.rxns = cell(2*length(model.rxns),1);
modelIrrev.rxnNames = cell(2*length(model.rxns),1);
modelIrrev.rev = zeros(2*length(model.rxns),1);
modelIrrev.lb = zeros(2*length(model.rxns),1);
modelIrrev.ub = zeros(2*length(model.rxns),1);
modelIrrev.c = zeros(2*length(model.rxns),1);
matchRev = zeros(2*length(model.rxns),1);

nRxns = size(model.S,2);
irrev2rev = zeros(2*length(model.rxns),1);

rev2irrev = cell(length(model.rxns),1);

%loop through each column/rxn in the S matrix building the irreversible
%model
cnt = 0;
for i = 1:nRxns
    cnt = cnt + 1;
    
    %expand the new model (same for both irrev & rev rxns
    modelIrrev.rev(cnt) = model.rev(i);
    irrev2rev(cnt) = i;
    
    % Reaction entirely in the positive direction
    if (model.ub(i) > 0 && model.lb(i) >= 0)
        % Keep positive upper bound
        modelIrrev.ub(cnt) = model.ub(i);
        modelIrrev.lb(cnt) = model.lb(i);
        modelIrrev.S(:,cnt) = model.S(:,i);
        modelIrrev.c(cnt) = model.c(i);
        modelIrrev.rxns{cnt} = [model.rxns{i} '_f'];
        modelIrrev.rxnNames{cnt} = [model.rxnNames{i} ' (fwd)'];
        modelIrrev.rev(cnt) = true;
        matchRev(cnt) = 0;
        rev2irrev{i,1} = cnt;
    end
    
    % Reaction entirely in the negative direction
    if (model.ub(i) <= 0 && model.lb(i) < 0)
        % Retain original bounds but reversed
        modelIrrev.ub(cnt,1) = -model.lb(i);
        modelIrrev.lb(cnt,1) = -model.ub(i);
        modelIrrev.S(:,cnt) = -model.S(:,i);
        modelIrrev.c(cnt,1) = max(-model.c(i),0);
        modelIrrev.rxns{cnt,1} = [model.rxns{i} '_r'];
        modelIrrev.rxnNames{cnt,1} = [model.rxnNames{i} ' (rev)'];
        modelIrrev.rev(cnt) = false;
        
        matchRev(cnt) = 0;
        rev2irrev{i,1} = cnt;
    end
    
    % Reaction entirely in both directions
    if (model.ub(i) > 0 && model.lb(i) < 0)
        modelIrrev.ub(cnt) = model.ub(i);
        modelIrrev.lb(cnt) = 0;
        modelIrrev.S(:,cnt) = model.S(:,i);
        modelIrrev.c(cnt) = max(model.c(i),0);
        modelIrrev.rxns{cnt} = [model.rxns{i} '_f'];
        modelIrrev.rxnNames{cnt} = [model.rxnNames{i} ' (fwd)'];
        modelIrrev.rev(cnt) = true;
        
        cnt = cnt + 1;
        
        modelIrrev.ub(cnt) = -model.lb(i);
        modelIrrev.lb(cnt) = 0;
        modelIrrev.S(:,cnt) = -model.S(:,i);
        modelIrrev.c(cnt) = max(model.c(i),0);
        modelIrrev.rxns{cnt} = [model.rxns{i} '_r'];
        modelIrrev.rxnNames{cnt} = [model.rxnNames{i} ' (rev)'];
        modelIrrev.rev(cnt) = true;
        
        matchRev(cnt) = cnt - 1;
        matchRev(cnt-1) = cnt;
        rev2irrev{i} = [cnt-1 cnt];
        irrev2rev(cnt) = i;
    end
    
end

rev2irrev = columnVector(rev2irrev);
irrev2rev = irrev2rev(1:cnt);
irrev2rev = columnVector(irrev2rev);

% Build final structure
modelIrrev.S = modelIrrev.S(:,1:cnt);
modelIrrev.ub = columnVector(modelIrrev.ub(1:cnt,1));
modelIrrev.lb = columnVector(modelIrrev.lb(1:cnt,1));
modelIrrev.c = columnVector(modelIrrev.c(1:cnt,1));
modelIrrev.rev = modelIrrev.rev(1:cnt,1);
modelIrrev.rev = columnVector(modelIrrev.rev == 1);
modelIrrev.rxns = columnVector(modelIrrev.rxns(1:cnt,1));
modelIrrev.rxnNames = columnVector(modelIrrev.rxnNames(1:cnt,1));
modelIrrev.mets = model.mets;
modelIrrev.metNames = model.metNames;
matchRev = columnVector(matchRev(1:cnt));
modelIrrev.match = matchRev;
if (isfield(model,'b'))
    modelIrrev.b = model.b;
end
if isfield(model,'description')
    modelIrrev.description = [model.description ' irreversible'];
end
if isfield(model,'subSystems')
    modelIrrev.subSystems = model.subSystems(irrev2rev);
end
if isfield(model,'genes')
    modelIrrev.genes = model.genes;
    genemtxtranspose = model.rxnGeneMat';
    modelIrrev.rxnGeneMat = genemtxtranspose(:,irrev2rev)';
    modelIrrev.rules = model.rules(irrev2rev);
end
modelIrrev.reversibleModel = false;
