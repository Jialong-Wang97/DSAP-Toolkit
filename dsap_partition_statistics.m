function result=dsap_partition_statistics(partition,vessels,aif,numerical_valid,nonfinite)
% Fixed spatial partition vs. exclusion mask vs. numerical validity.
    masks={partition.CortexMask;partition.SubcortexMask;partition.OuterMask};
    assert(~any(masks{1}&masks{2},'all')&&isequal(masks{1}|masks{2},masks{3}));
    names={'皮层';'皮层下';'颅内合并'};tic_masks=cell(3,1);parameter_masks=cell(3,1);
    geometry=zeros(3,1);vessel_count=geometry;aif_count=geometry;bad_input=geometry;tic_count=geometry;valid_count=geometry;
    for k=1:3
        geometry(k)=nnz(masks{k});vessel_count(k)=nnz(masks{k}&vessels&~aif);
        aif_count(k)=nnz(masks{k}&aif);
        clean=masks{k}&~vessels&~aif;
        bad_input(k)=nnz(clean&nonfinite);
        tic_masks{k}=clean&~nonfinite;
        parameter_masks{k}=tic_masks{k}&numerical_valid;
        tic_count(k)=nnz(tic_masks{k});valid_count(k)=nnz(parameter_masks{k});
    end
    coverage=100*valid_count./max(tic_count,1);
    table_data=table(names,geometry,vessel_count,aif_count,bad_input,tic_count,valid_count, ...
        tic_count-valid_count,coverage,'VariableNames',{'ROI','GeometryPixels','ExcludedVesselPixels', ...
        'ExcludedAIFPixels','NonfiniteInputPixels','TICPixels','PerfusionValidPixels', ...
        'InvalidPerfusionPixels','PerfusionCoveragePercent'});
    result=struct('Names',{names},'GeometryMasks',{masks},'TICMasks',{tic_masks}, ...
        'ParameterMasks',{parameter_masks},'Coverage',table_data);
end
