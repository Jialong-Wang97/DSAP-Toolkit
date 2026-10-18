function [rgb, labels, palette] = dsap_signal_quality_rgb(reference,features,limit_mask,vessels,aif,tissue)
% 0 outside; 1 no enhancement; 2 uncertain; 3 tissue; 4 vessel; 5 AIF;
% 6 invalid fit; 7 MIP dark spatial background.
    labels=features.Labels;
    labels(features.SignalValidMask & ~tissue & limit_mask)=2;
    if isfield(features,'NumericallyUnreliableMask')
        labels(features.NumericallyUnreliableMask)=6;
    end
    labels(tissue)=3;
    labels(vessels & limit_mask)=4;
    labels(aif & limit_mask)=5;
    labels(~limit_mask)=0;
    palette=[0.12 0.12 0.12; 0.35 0.35 0.35; 1 0.8 0.05; ...
        0.1 0.9 0.25; 1 0.15 0.12; 0.05 0.8 1; 0.75 0.35 1; 0.16 0.16 0.16];
    reference=single(mat2gray(reference));
    rgb=repmat(reference,1,1,3);
    for category=0:7
        selected=labels==category;
        alpha=0.40;
        if category==0, alpha=0.75; end
        for c=1:3
            plane=rgb(:,:,c);
            plane(selected)=(1-alpha)*plane(selected)+alpha*palette(category+1,c);
            rgb(:,:,c)=plane;
        end
    end
end
