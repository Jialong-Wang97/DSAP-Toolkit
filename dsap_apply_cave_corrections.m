function [mask,tissue,model,features]=dsap_apply_cave_corrections(model,features,added,restored,scope,brain,aif)
% Explicit set operations; AIF remains excluded even when restoring tissue.
    shape=size(scope);
    assert(isequal(size(added),shape)&&isequal(size(restored),shape)&& ...
        isequal(size(brain),shape)&&isequal(size(aif),shape),'CAVE 手动调整尺寸不一致。');
    scope=logical(scope);automatic=features.AutomaticVesselMask&scope;
    added=logical(added)&scope;restored=logical(restored)&scope;
    mask=(automatic|added)&~restored&scope;
    tissue=logical(brain)&scope&~mask&~aif;
    features.ManualAddedMask=added;features.ManualRestoredMask=restored;
    model.ManuallyCorrected=any(mask~=automatic,'all');
    model.ExcludedPixelCount=nnz(mask);
    model.ExcludedPixelFraction=nnz(mask)/max(nnz(scope),1);
    model.ManualAddedPixelCount=nnz(mask&~automatic);
    model.ManualRestoredPixelCount=nnz(automatic&~mask);
    model.ManualCorrectionOperation='((CAVE artery OR vein) UNION manual added) MINUS manual restored; intersect scope; AIF separately excluded';
end
