function mask=dsap_orientation_transform(original,mapping)
% Exact pixel permutations only. No resampling, resizing or color inference.
    assert(islogical(original)&&ismatrix(original),'DSAP:OrientationMask','Expected a logical 2-D mask.');
    switch char(mapping)
        case 'identity',mask=original;
        case 'transpose',mask=original.';
        case 'flipud',mask=flipud(original);
        case 'fliplr',mask=fliplr(original);
        case 'flipud+fliplr',mask=flipud(fliplr(original));
        case 'transpose+flipud',mask=flipud(original.');
        case 'transpose+fliplr',mask=fliplr(original.');
        case 'transpose+flipud+fliplr',mask=flipud(fliplr(original.'));
        otherwise,error('DSAP:OrientationMapping','Unknown pixel mapping: %s',char(mapping));
    end
end
