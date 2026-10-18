% Copyright (C) 2026 王嘉龙. SPDX-License-Identifier: GPL-3.0-only
function filtered = centered_temporal_gaussian_filter(data, dt)
%CENTERED_TEMPORAL_GAUSSIAN_FILTER Centered Gaussian filtering in time.

    validateattributes(data, {'numeric'}, {'nonempty'});
    validateattributes(dt, {'numeric'}, {'scalar', 'finite', 'positive'});
    nominal_width = max(3, round(1 / double(dt)));
    if mod(nominal_width, 2) == 0
        nominal_width = nominal_width + 1;
    end
    weights = gausswin(nominal_width, 1.66);
    weights = weights / sum(weights);

    frame_count = size(data, 1);
    pad_before = floor((nominal_width - 1) / 2);
    pad_after = nominal_width - 1 - pad_before;
    indices = [ones(1, pad_before), 1:frame_count, ...
        frame_count * ones(1, pad_after)];
    kernel_shape = [nominal_width, ones(1, max(1, ndims(data) - 1))];
    kernel = reshape(cast(weights, 'like', data), kernel_shape);
    % Bound padding/convolution temporaries and service close/cancel events
    % between spatial blocks. Time samples and endpoint treatment unchanged.
    dsap_task_control('check');
    flat=reshape(data,frame_count,[]);
    block_size=max(1,floor(16*1024^2/(8*numel(indices))));
    if size(flat,2)<=block_size
        filtered=convn(data(indices,:,:),kernel,'valid');
    elseif ndims(data)==3
        % Preserve the original 3-D convolution path. Flattening to 2-D
        % changes accumulation order and can move argmax on a flat TIC peak.
        filtered=zeros(size(data),'like',data);
        column_block=max(2,floor(block_size/size(data,2)));
        first=1;
        while first<=size(data,3)
            dsap_task_control('check');
            last=min(first+column_block-1,size(data,3));
            if last==size(data,3)-1,last=size(data,3);end
            filtered(:,:,first:last)=convn(data(indices,:,first:last),kernel,'valid');
            first=last+1;
        end
    else
        filtered=zeros(size(flat),'like',data);
        for first=1:block_size:size(flat,2)
            dsap_task_control('check');
            pixels=first:min(first+block_size-1,size(flat,2));
            filtered(:,pixels)=convn(flat(indices,pixels),cast(weights,'like',data),'valid');
        end
        filtered=reshape(filtered,size(data));
    end
    dsap_task_control('check');
end
