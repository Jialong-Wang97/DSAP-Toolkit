function dsap_write_curve_tables(output_dir, roi_names, original_time_seconds, time_seconds, ...
        native_aif_curve, original_aif_curve, filtered_aif_curve, ...
        native_roi_tics, original_roi_tics, roi_tics, roi_irfs)
    original_table = table(original_time_seconds(:), native_aif_curve(:), ...
        original_aif_curve(:), ...
        'VariableNames', {'Time_s', 'AIF_native_raw', 'AIF_enhancement'});
    processed_table = table(time_seconds(:), filtered_aif_curve(:), ...
        'VariableNames', {'Time_s', 'AIF_filtered'});

    native_names = cell(numel(roi_names), 1);
    original_names = cell(numel(roi_names), 1);
    tic_names = cell(numel(roi_names), 1);
    irf_names = cell(numel(roi_names), 1);
    for index = 1:numel(roi_names)
        base_name = matlab.lang.makeValidName(sprintf('ROI_%02d_%s', ...
            index, roi_names{index}));
        native_names{index} = matlab.lang.makeValidName(['TIC_native_raw_', base_name]);
        original_names{index} = matlab.lang.makeValidName(['TIC_enhancement_', base_name]);
        tic_names{index} = matlab.lang.makeValidName(['TIC_filtered_', base_name]);
        irf_names{index} = matlab.lang.makeValidName(['IRF_', base_name]);
    end
    all_original_names = matlab.lang.makeUniqueStrings( ...
        [native_names; original_names], ...
        original_table.Properties.VariableNames);
    native_names = all_original_names(1:numel(roi_names));
    original_names = all_original_names(numel(roi_names) + 1:end);
    processed_names = matlab.lang.makeUniqueStrings([tic_names; irf_names], ...
        processed_table.Properties.VariableNames);
    tic_names = processed_names(1:numel(roi_names));
    irf_names = processed_names(numel(roi_names) + 1:end);

    for index = 1:numel(roi_names)
        original_table.(native_names{index}) = native_roi_tics{index}(:);
        original_table.(original_names{index}) = original_roi_tics{index}(:);
        processed_table.(tic_names{index}) = roi_tics{index}(:);
        processed_table.(irf_names{index}) = roi_irfs{index}(:);
    end
    writetable(original_table, fullfile(output_dir, 'original_TIC_curves.csv'));
    writetable(processed_table, fullfile(output_dir, 'resampled_filtered_TIC_IRF_curves.csv'));
end

