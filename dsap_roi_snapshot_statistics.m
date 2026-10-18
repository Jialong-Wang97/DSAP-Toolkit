function stats=dsap_roi_snapshot_statistics(snapshot,vessels,aif,valid,nonfinite)
% Execute existing validated statistics by explicit policy, never by Source.
    dsap_validate_roi_snapshot(snapshot);
    expected=snapshot.ROIs(strcmp({snapshot.ROIs.Role},'AIF')).Mask;
    assert(isequaln(aif,expected),'DSAP:SnapshotAIF','Statistics AIF differs from frozen AIF.');
    plan=snapshot.StatisticsPlan;ids={snapshot.ROIs.ID};
    [present,index]=ismember(plan.ROIIds,ids);assert(all(present));
    masks={snapshot.ROIs(index).Mask}';
    switch plan.Version
        case 'partition-v1'
            assert(numel(masks)==3,'DSAP:SnapshotRows','Partition requires three ordered masks.');
            partition=struct('CortexMask',masks{1},'SubcortexMask',masks{2},'OuterMask',masks{3});
            stats=dsap_partition_statistics(partition,vessels,aif,valid,nonfinite);
        case 'imported-v1'
            imported=struct('Masks',{masks},'Names',{plan.Names});
            stats=dsap_imported_statistics(imported,snapshot.AnalysisScope.BandMask,vessels,aif,valid,nonfinite);
        otherwise
            error('DSAP:SnapshotPolicy','Unknown statistics policy.');
    end
end
