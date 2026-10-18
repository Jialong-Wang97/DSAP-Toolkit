function summary = dsap_build_summary_table(names, masks, selected_frames, roi_types, ...
        merge_sources, CBF, CBV, Tmax, MTT, volume_map, peak_map, ttp_map, ...
        intensity_map, roi_irfs, time_seconds)
    count = numel(masks);
    roi_name = names(:);
    roi_type = roi_types(:);
    merged_from = merge_sources(:);
    selected_frame = selected_frames(:);
    area_pixels = zeros(count, 1);
    cbf_mean = zeros(count, 1);
    cbv_mean = zeros(count, 1);
    tmax_mean_s = zeros(count, 1);
    mtt_mean_s = zeros(count, 1);
    volume_mean = zeros(count, 1);
    peak_mean = zeros(count, 1);
    ttp_mean_s = zeros(count, 1);
    intensity_mean = zeros(count, 1);
    roi_irf_cbf = zeros(count, 1);
    roi_irf_cbv = zeros(count, 1);
    roi_irf_tmax_s = zeros(count, 1);
    roi_irf_mtt_s = zeros(count, 1);
    dt = median(diff(time_seconds));

    for index = 1:count
        mask = masks{index};
        area_pixels(index) = nnz(mask);
        cbf_mean(index) = mean(CBF(mask), 'omitnan');
        cbv_mean(index) = mean(CBV(mask), 'omitnan');
        tmax_mean_s(index) = mean(Tmax(mask), 'omitnan');
        mtt_mean_s(index) = mean(MTT(mask), 'omitnan');
        volume_mean(index) = mean(volume_map(mask), 'omitnan');
        peak_mean(index) = mean(peak_map(mask), 'omitnan');
        ttp_mean_s(index) = mean(ttp_map(mask), 'omitnan');
        intensity_mean(index) = mean(intensity_map(mask), 'omitnan');
        mean_irf = double(roi_irfs{index}(:));
        if ~any(isfinite(mean_irf))
            roi_irf_cbf(index)=NaN;roi_irf_cbv(index)=NaN;roi_irf_tmax_s(index)=NaN;roi_irf_mtt_s(index)=NaN;
            continue;
        end
        [roi_irf_cbf(index), peak_index] = max(mean_irf);
        roi_irf_tmax_s(index) = time_seconds(peak_index);
        roi_irf_cbv(index) = dt * sum(mean_irf, 'omitnan');
        roi_irf_mtt_s(index) = roi_irf_cbv(index) / ...
            max(roi_irf_cbf(index), eps);
    end

    summary = table(roi_name, roi_type, merged_from, selected_frame, ...
        area_pixels, cbf_mean, cbv_mean, ...
        tmax_mean_s, mtt_mean_s, volume_mean, peak_mean, ttp_mean_s, ...
        intensity_mean, roi_irf_cbf, roi_irf_cbv, roi_irf_tmax_s, ...
        roi_irf_mtt_s, 'VariableNames', {'ROI', 'ROIType', 'MergedFrom', ...
        'SelectedFrame', 'AreaPixels', 'CBF', 'CBV', 'Tmax_s', 'MTT_s', ...
        'Volume', 'Peak', 'TTP_s', 'Intensity', 'ROIIRF_CBF', 'ROIIRF_CBV', ...
        'ROIIRF_Tmax_s', 'ROIIRF_MTT_s'});
end

