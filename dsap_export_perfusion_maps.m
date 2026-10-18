function fig=dsap_export_perfusion_maps(output_dir,reference,aif,limits,tissue,vessels,CBF,CBV,Tmax,MTT)
% Explicit export compatibility entry. Display-only callers use dsap_perfusion_view.
    dsap_task_control('check');
    r=struct('reference_image',reference,'aif_mask',aif,'cranial_limits',limits, ...
        'valid_tissue_mask',tissue,'large_vessel_mask',vessels,'CBF',CBF,'CBV',CBV,'Tmax',Tmax,'MTT',MTT);
    fig=dsap_perfusion_view(r);
    try
        dsap_export_perfusion_view(output_dir,fig);
        dsap_task_control('check');
        if nargout>0,fig.Visible=get(groot,'DefaultFigureVisible');else,dsap_safe_delete(fig);end
    catch exception
        dsap_safe_delete(fig);rethrow(exception);
    end
end