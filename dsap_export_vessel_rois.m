function dsap_export_vessel_rois(folder,reference,result,original_time,time)
    parameters=[result.Summary result.Coverage(:,2:end)];parameters.Status=result.Status;
    writetable(parameters,fullfile(folder,'CAVE_vessel_ROI_parameters.csv'));
    provenance=table(result.Names,cellfun(@nnz,result.GeometryMasks),cellfun(@nnz,result.Masks), ...
        cellfun(@nnz,result.ParameterMasks),result.AIFOverlapPixels, ...
        repmat(nnz(result.OverlapMask),2,1),'VariableNames', ...
        {'ROI','GeometryPixels','TICPixels','PerfusionValidPixels','IncludedAIFPixels','AVOverlapPixels'});
    writetable(provenance,fullfile(folder,'CAVE_vessel_ROI_scope.csv'));
    original=table(original_time(:),'VariableNames',{'Time_s'});
    filtered=table(time(:),'VariableNames',{'Time_s'});
    for k=1:2
        name=result.Names{k};
        imwrite(result.GeometryMasks{k},fullfile(folder,[name '_ROI_geometry.png']));
        imwrite(result.Masks{k},fullfile(folder,[name '_ROI_mask.png']));
        imwrite(result.ParameterMasks{k},fullfile(folder,[name '_ROI_valid_parameters.png']));
        original.([name '_native_raw'])=result.NativeTIC{k}(:);
        original.([name '_enhancement'])=result.OriginalTIC{k}(:);
        filtered.([name '_TIC'])=result.TIC{k}(:);
        filtered.([name '_IRF'])=result.IRF{k}(:);
    end
    writetable(original,fullfile(folder,'CAVE_vessel_original_TIC.csv'));
    writetable(filtered,fullfile(folder,'CAVE_vessel_filtered_TIC_IRF.csv'));
    save(fullfile(folder,'CAVE_vessel_ROI_results.mat'),'result','original_time','time','-v7');
    fig=figure('Visible','off','Color','w','Position',[50 50 1350 700]);
    cleanup=onCleanup(@()dsap_safe_delete(fig)); %#ok<NASGU>
    layout=tiledlayout(fig,2,2);colors=[1 .15 .1;.1 .4 1];
    for k=1:2
        ax=nexttile(layout);imshow(reference,[],'Parent',ax);hold(ax,'on');
        h=imshow(repmat(reshape(colors(k,:),1,1,3),[size(reference) 1]),'Parent',ax);
        h.AlphaData=.5*single(result.Masks{k});
        title(ax,sprintf('%s | %d pixels',result.Names{k},nnz(result.Masks{k})),'Interpreter','none');
    end
    ax=nexttile(layout);hold(ax,'on');
    for k=1:2,plot(ax,original_time,result.NativeTIC{k},'Color',colors(k,:),'DisplayName',result.Names{k});end
    title(ax,'动脉 / 静脉原始灰度 TIC');xlabel(ax,'时间 (s)');grid(ax,'on');legend(ax,'Interpreter','none');
    ax=nexttile(layout);hold(ax,'on');
    for k=1:2,plot(ax,time,result.TIC{k},'Color',colors(k,:),'DisplayName',result.Names{k});end
    title(ax,'动脉 / 静脉滤波后增强 TIC');xlabel(ax,'时间 (s)');grid(ax,'on');legend(ax,'Interpreter','none');
    exportgraphics(fig,fullfile(folder,'CAVE_vessel_ROI_overview.png'),'Resolution',140);
end
