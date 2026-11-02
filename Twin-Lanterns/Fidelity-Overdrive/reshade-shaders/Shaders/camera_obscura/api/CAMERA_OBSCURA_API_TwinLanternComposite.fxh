#ifndef CAMERA_OBSCURA_API_TWIN_LANTERN_COMPOSITE_FXH
#define CAMERA_OBSCURA_API_TWIN_LANTERN_COMPOSITE_FXH

#include "CAMERA_OBSCURA_API_TwinLanternReconstruction.fxh"

struct CAMERA_OBSCURA_API_TL09CompositeEvidence
{
    float3 source_rgb;
    float3 indirect_rgb;
    float3 weighted_indirect_rgb;
    float3 bounded_indirect_rgb;
    float3 remaining_room_rgb;
    float3 bounded_contribution_rgb;
    float3 final_rgb;
    float evidence;
    float receiver_valid;
    float enabled;
    float strength;
    float maximum_contribution;
    float admission;
    float application;
    float rejection;
    float rejection_code;
    float containment_activity;
    float source_preserve_delta;
    float bounds_valid;
};

CAMERA_OBSCURA_API_TL09CompositeEvidence
CAMERA_OBSCURA_API_DefaultTL09CompositeEvidence()
{
    CAMERA_OBSCURA_API_TL09CompositeEvidence evidence;
    evidence.source_rgb = float3(0.0, 0.0, 0.0);
    evidence.indirect_rgb = float3(0.0, 0.0, 0.0);
    evidence.weighted_indirect_rgb = float3(0.0, 0.0, 0.0);
    evidence.bounded_indirect_rgb = float3(0.0, 0.0, 0.0);
    evidence.remaining_room_rgb = float3(0.0, 0.0, 0.0);
    evidence.bounded_contribution_rgb = float3(0.0, 0.0, 0.0);
    evidence.final_rgb = float3(0.0, 0.0, 0.0);
    evidence.evidence = 0.0;
    evidence.receiver_valid = 0.0;
    evidence.enabled = 0.0;
    evidence.strength = 0.0;
    evidence.maximum_contribution = 0.0;
    evidence.admission = 0.0;
    evidence.application = 0.0;
    evidence.rejection = 1.0;
    evidence.rejection_code = 1.0;
    evidence.containment_activity = 0.0;
    evidence.source_preserve_delta = 0.0;
    evidence.bounds_valid = 1.0;
    return evidence;
}

CAMERA_OBSCURA_API_TL09CompositeEvidence
CAMERA_OBSCURA_API_BuildTL09Composite(
    float3 sourceRgb,
    float3 resolvedIndirectRgb,
    float trustedWeight,
    float receiverValid,
    float enabled,
    float strength,
    float maximumContribution)
{
    CAMERA_OBSCURA_API_TL09CompositeEvidence result =
        CAMERA_OBSCURA_API_DefaultTL09CompositeEvidence();
    float3 safeSource = saturate(sourceRgb);
    float3 safeIndirect = saturate(resolvedIndirectRgb);
    float safeEvidence = saturate(trustedWeight);
    float safeReceiver = saturate(receiverValid);
    float safeEnabled = saturate(enabled);
    float safeStrength = max(strength, 0.0);
    float safeMaximum = saturate(maximumContribution);
    float hasEvidence = step(0.000001, safeEvidence);
    float hasStrength = step(0.000001, safeStrength);
    float admission =
        safeEnabled * safeReceiver * hasEvidence * hasStrength;
    float3 weightedIndirect =
        safeIndirect * safeEvidence * safeStrength * admission;
    float3 boundedIndirect = min(
        max(weightedIndirect, 0.0.xxx),
        safeMaximum.xxx);
    float3 remainingRoom = max(
        float3(1.0, 1.0, 1.0) - safeSource,
        0.0.xxx);
    float3 channelCeiling = min(safeMaximum.xxx, remainingRoom);
    float3 boundedContribution = min(boundedIndirect, channelCeiling);
    float3 finalRgb = safeSource + boundedContribution;
    float3 containmentDelta = max(
        weightedIndirect - boundedContribution,
        0.0.xxx);
    float contributionMaximum = max(
        max(boundedContribution.r, boundedContribution.g),
        boundedContribution.b);
    float remainingMaximum = max(
        max(remainingRoom.r, remainingRoom.g),
        remainingRoom.b);
    float indirectMaximum = max(
        max(weightedIndirect.r, weightedIndirect.g),
        weightedIndirect.b);
    float application = admission * step(0.000001, contributionMaximum);
    float rejectionCode = 0.0;

    if (safeEnabled < 0.5)
    {
        rejectionCode = 1.0;
    }
    else if (safeReceiver < 0.5)
    {
        rejectionCode = 2.0;
    }
    else if (hasEvidence < 0.5)
    {
        rejectionCode = 3.0;
    }
    else if (hasStrength < 0.5)
    {
        rejectionCode = 4.0;
    }
    else if (remainingMaximum < 0.000001)
    {
        rejectionCode = 5.0;
    }
    else if (indirectMaximum < 0.000001)
    {
        rejectionCode = 6.0;
    }

    float lowerViolation = max(
        max(-boundedContribution.r, -boundedContribution.g),
        -boundedContribution.b);
    float ceilingViolation = max(
        max(
            boundedContribution.r - channelCeiling.r,
            boundedContribution.g - channelCeiling.g),
        boundedContribution.b - channelCeiling.b);
    float outputViolation = max(
        max(finalRgb.r - 1.0, finalRgb.g - 1.0),
        finalRgb.b - 1.0);
    float boundsViolation = max(
        max(lowerViolation, ceilingViolation),
        outputViolation);

    result.source_rgb = safeSource;
    result.indirect_rgb = safeIndirect;
    result.weighted_indirect_rgb = weightedIndirect;
    result.bounded_indirect_rgb = boundedIndirect;
    result.remaining_room_rgb = remainingRoom;
    result.bounded_contribution_rgb = boundedContribution;
    result.final_rgb = finalRgb;
    result.evidence = safeEvidence;
    result.receiver_valid = safeReceiver;
    result.enabled = safeEnabled;
    result.strength = safeStrength;
    result.maximum_contribution = safeMaximum;
    result.admission = admission;
    result.application = application;
    result.rejection = 1.0 - application;
    result.rejection_code = rejectionCode;
    result.containment_activity = saturate(CAMERA_OBSCURA_Luma(
        containmentDelta));
    result.source_preserve_delta = CAMERA_OBSCURA_Luma(
        abs(finalRgb - safeSource));
    result.bounds_valid = 1.0 - step(0.000001, boundsViolation);
    return result;
}

#endif // CAMERA_OBSCURA_API_TWIN_LANTERN_COMPOSITE_FXH
