function dsap_export_partition(folder,reference,partition,statistics,vessels,aif,quality)
    dsap_task_control('check');
    geometry=statistics.GeometryMasks;names={'cortex','subcortex','combined'};
    for k=1:3
        imwrite(geometry{k},fullfile(folder,[names{k} '_geometry_mask.png']));
        imwrite(statistics.TICMasks{k},fullfile(folder,[names{k} '_nonvessel_TIC_mask.png']));
        imwrite(statistics.ParameterMasks{k},fullfile(folder,[names{k} '_perfusion_valid_mask.png']));
    end
    labels=uint8(partition.CortexMask)+2*uint8(partition.SubcortexMask);
    imwrite(labels,fullfile(folder,'partition_labels.png'));
    writetable(statistics.Coverage,fullfile(folder,'partition_coverage.csv'));
    template_box=[1 partition.CranialLimits.UpperRow size(reference,2)-1 ...
        partition.CranialLimits.LowerRow-partition.CranialLimits.UpperRow];
    if isfield(partition,'TemplateFitBox'),template_box=partition.TemplateFitBox;end
    template=dsap_partition_template('savegeometry',partition,template_box);
    save(fullfile(folder,'partition_template.mat'),'template');
    save(fullfile(folder,'partition_results.mat'),'partition','statistics','labels');
    r=struct('reference_image',reference,'partition',partition,'partition_stats',statistics, ...
        'large_vessel_mask',vessels,'aif_mask',aif);
    fig=dsap_partition_view(r);
    cleanup=onCleanup(@() dsap_safe_delete(fig)); %#ok<NASGU>
    exportgraphics(fig,fullfile(folder,'partition_review.png'),'Resolution',140);
    imwrite(quality.UncertainMask & partition.OuterMask,fullfile(folder,'partition_weak_signal_advisory.png'));
end