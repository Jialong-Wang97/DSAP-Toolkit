function dsap_export_cave(folder,reference,model,features,final_mask)
% Keep raw automatic candidates separate from the final user-reviewed mask.
    dsap_task_control('check');
    imwrite(features.ArteryMask,fullfile(folder,'CAVE_artery_mask.png'));
    imwrite(features.VeinMask,fullfile(folder,'CAVE_vein_mask.png'));
    imwrite(features.AutomaticVesselMask,fullfile(folder,'CAVE_automatic_union_mask.png'));
    imwrite(features.ManualAddedMask,fullfile(folder,'CAVE_manual_added_mask.png'));
    imwrite(features.ManualRestoredMask,fullfile(folder,'CAVE_manual_restored_mask.png'));
    save(fullfile(folder,'CAVE_segmentation.mat'),'model','features','final_mask','-v7');
    fig=figure('Visible','off','Color','w','Position',[40 40 1400 530]);
    cleanup=onCleanup(@() dsap_safe_delete(fig)); %#ok<NASGU>
    t=tiledlayout(fig,1,3,'Padding','compact');
    ax=nexttile(t);show(ax,reference,false(size(reference)));title(ax,'原始最大增强投影');
    ax=nexttile(t);show(ax,reference,features.AutomaticVesselMask);title(ax,'CAVE 自动动静脉并集（含细血管）');
    ax=nexttile(t);show(ax,reference,final_mask);title(ax,'最终确认排除区域');
    exportgraphics(fig,fullfile(folder,'CAVE_reviewed_comparison.png'),'Resolution',140);
end

function show(ax,reference,mask)
    imshow(reference,[],'Parent',ax);hold(ax,'on');
    h=imshow(cat(3,zeros(size(mask)),.9*ones(size(mask)),ones(size(mask))),'Parent',ax);
    h.AlphaData=.6*single(mask);
end
