#ifndef CAMERA_OBSCURA_ATOMIC_DEBUG_FXH
#define CAMERA_OBSCURA_ATOMIC_DEBUG_FXH

#include "CAMERA_OBSCURA_AtomicCommon.fxh"

#define CAMERA_OBSCURA_DEBUG_VIEW_COMPOSITE 0
#define CAMERA_OBSCURA_DEBUG_VIEW_DDA_HIT 1
#define CAMERA_OBSCURA_DEBUG_VIEW_MARCH_HIT 2
#define CAMERA_OBSCURA_DEBUG_VIEW_AGREEMENT 3
#define CAMERA_OBSCURA_DEBUG_VIEW_DDA_CONTRIBUTION 4
#define CAMERA_OBSCURA_DEBUG_VIEW_MARCH_CONTRIBUTION 5
#define CAMERA_OBSCURA_DEBUG_VIEW_REASON 6
#define CAMERA_OBSCURA_DEBUG_VIEW_COMPOSITE_DELTA 7
#define CAMERA_OBSCURA_DEBUG_VIEW_PROVIDER_BALANCE 8
#define CAMERA_OBSCURA_DEBUG_VIEW_SOURCE 9

#ifndef CAMERA_OBSCURA_DEBUG_AGREEMENT_WEAK_WEIGHT
#define CAMERA_OBSCURA_DEBUG_AGREEMENT_WEAK_WEIGHT 0.65
#endif

#ifndef CAMERA_OBSCURA_DEBUG_AGREEMENT_DISPLAY_MIN
#define CAMERA_OBSCURA_DEBUG_AGREEMENT_DISPLAY_MIN 0.20
#endif

#ifndef CAMERA_OBSCURA_DEBUG_AGREEMENT_DISPLAY_MAX
#define CAMERA_OBSCURA_DEBUG_AGREEMENT_DISPLAY_MAX 1.00
#endif

#ifndef CAMERA_OBSCURA_DEBUG_AGREEMENT_GREEN_G
#define CAMERA_OBSCURA_DEBUG_AGREEMENT_GREEN_G 0.035
#endif

#ifndef CAMERA_OBSCURA_DEBUG_AGREEMENT_GREEN_B
#define CAMERA_OBSCURA_DEBUG_AGREEMENT_GREEN_B 0.010
#endif

#ifndef CAMERA_OBSCURA_DEBUG_AGREEMENT_WEAK_R
#define CAMERA_OBSCURA_DEBUG_AGREEMENT_WEAK_R 0.035
#endif

#ifndef CAMERA_OBSCURA_DEBUG_AGREEMENT_WEAK_G
#define CAMERA_OBSCURA_DEBUG_AGREEMENT_WEAK_G 0.025
#endif

#ifndef CAMERA_OBSCURA_DEBUG_AGREEMENT_ISSUE_BLEND
#define CAMERA_OBSCURA_DEBUG_AGREEMENT_ISSUE_BLEND 0.78
#endif

#ifndef CAMERA_OBSCURA_DEBUG_AGREEMENT_NO_EVIDENCE_BLEND
#define CAMERA_OBSCURA_DEBUG_AGREEMENT_NO_EVIDENCE_BLEND 0.35
#endif

#ifndef CAMERA_OBSCURA_DEBUG_CONTRIBUTION_LUMA_MIN
#define CAMERA_OBSCURA_DEBUG_CONTRIBUTION_LUMA_MIN 0.020
#endif

#ifndef CAMERA_OBSCURA_DEBUG_CONTRIBUTION_LUMA_MAX
#define CAMERA_OBSCURA_DEBUG_CONTRIBUTION_LUMA_MAX 0.180
#endif

#ifndef CAMERA_OBSCURA_DEBUG_CONTRIBUTION_WEIGHT_GAIN
#define CAMERA_OBSCURA_DEBUG_CONTRIBUTION_WEIGHT_GAIN 1.00
#endif

#ifndef CAMERA_OBSCURA_DEBUG_CONTRIBUTION_CONTEXT
#define CAMERA_OBSCURA_DEBUG_CONTRIBUTION_CONTEXT 0.25
#endif

float3 CAMERA_OBSCURA_DebugHeat(float value)
{
    float v = saturate(value);
    float3 cold = float3(0.035, 0.080, 0.300);
    float3 mid = float3(0.090, 0.650, 0.320);
    float3 hot = float3(1.000, 0.760, 0.080);
    float3 whiteHot = float3(1.000, 0.970, 0.930);
    float3 a = lerp(cold, mid, saturate(v * 2.0));
    float3 b = lerp(mid, hot, saturate(v * 2.0 - 1.0));
    float3 c = lerp(hot, whiteHot, saturate(v * 4.0 - 3.0));
    return saturate(lerp(lerp(a, b, step(0.5, v)), c, step(0.75, v)));
}

float3 CAMERA_OBSCURA_DebugBackendColor(float backend)
{
    if (abs(backend - CAMERA_OBSCURA_BACKEND_DDA) < 0.5)
    {
        return float3(0.120, 0.550, 1.000);
    }

    if (abs(backend - CAMERA_OBSCURA_BACKEND_MARCH) < 0.5)
    {
        return float3(1.000, 0.420, 0.140);
    }

    return float3(0.180, 0.180, 0.220);
}

float3 CAMERA_OBSCURA_DebugSourceAnchor(float3 source)
{
    float luma = CAMERA_OBSCURA_Luma(source);
    return saturate(source * 0.12 + float3(luma, luma, luma) * 0.08);
}

float3 CAMERA_OBSCURA_DebugOverlay(float3 source, float3 signal)
{
    return saturate(CAMERA_OBSCURA_DebugSourceAnchor(source) + signal * 0.88);
}

float3 CAMERA_OBSCURA_DebugReasonColor(float reason)
{
    if (abs(reason - CAMERA_OBSCURA_REASON_HIT) < 0.5)
    {
        return float3(0.180, 0.920, 0.520);
    }

    if (abs(reason - CAMERA_OBSCURA_REASON_SCREEN_EXIT) < 0.5)
    {
        return float3(0.220, 0.430, 1.000);
    }

    if (abs(reason - CAMERA_OBSCURA_REASON_INVALID_DEPTH) < 0.5)
    {
        return float3(0.650, 0.120, 0.700);
    }

    if (abs(reason - CAMERA_OBSCURA_REASON_SELF_HIT) < 0.5)
    {
        return float3(0.950, 0.220, 0.250);
    }

    if (abs(reason - CAMERA_OBSCURA_REASON_INVALID_RAY) < 0.5)
    {
        return float3(0.800, 0.180, 0.180);
    }

    return float3(0.500, 0.500, 0.180);
}

float3 CAMERA_OBSCURA_DebugHit(CAMERA_OBSCURA_Hit hit)
{
    if (hit.hit > 0.5)
    {
        float3 carrier = CAMERA_OBSCURA_DebugBackendColor(hit.backend);
        float maxSteps =
            abs(hit.backend - CAMERA_OBSCURA_BACKEND_DDA) < 0.5 ?
            (float)CAMERA_OBSCURA_DDA_MAX_STEPS :
            (float)CAMERA_OBSCURA_MARCH_MAX_STEPS;
        float stepNorm = saturate(hit.step_index * CAMERA_OBSCURA_SafeRcp(maxSteps, 0.0));
        float confidence = saturate(hit.confidence);
        float deltaTrace = saturate(abs(hit.delta) * 192.0);
        float3 diagnostic = float3(stepNorm, confidence, deltaTrace);
        return saturate(lerp(
            carrier * (0.45 + 0.35 * confidence),
            diagnostic,
            0.32));
    }

    return saturate(
        CAMERA_OBSCURA_DebugReasonColor(hit.reason) *
        (0.45 + 0.55 * saturate(hit.confidence + 0.1)));
}

float3 CAMERA_OBSCURA_DebugContribution(CAMERA_OBSCURA_Contribution contribution)
{
    if (contribution.valid < 0.5)
    {
        return float3(0.0, 0.0, 0.0);
    }

    float indirectLuma = CAMERA_OBSCURA_Luma(contribution.indirect_rgb);
    float energy = smoothstep(
        CAMERA_OBSCURA_DEBUG_CONTRIBUTION_LUMA_MIN,
        CAMERA_OBSCURA_DEBUG_CONTRIBUTION_LUMA_MAX,
        indirectLuma);
    float weightSignal = saturate(
        contribution.weight *
        CAMERA_OBSCURA_DEBUG_CONTRIBUTION_WEIGHT_GAIN);
    float evidence = saturate(energy * weightSignal);
    evidence *= evidence;
    float3 heat = CAMERA_OBSCURA_DebugHeat(contribution.weight);
    float3 indirect = saturate(contribution.indirect_rgb * 3.0);

    return saturate(lerp(heat, indirect, 0.45) * evidence);
}

float3 CAMERA_OBSCURA_DebugContributionView(
    float3 source,
    CAMERA_OBSCURA_Contribution contribution)
{
    float3 signal = CAMERA_OBSCURA_DebugContribution(contribution);
    float signalLuma = CAMERA_OBSCURA_Luma(signal);
    float context = smoothstep(0.010, 0.060, signalLuma);
    return saturate(
        CAMERA_OBSCURA_DebugSourceAnchor(source) *
        CAMERA_OBSCURA_DEBUG_CONTRIBUTION_CONTEXT *
        context +
        signal * 0.92);
}

float3 CAMERA_OBSCURA_DebugCompositeDelta(float3 source, float3 composite)
{
    float3 delta = max(composite - source, float3(0.0, 0.0, 0.0));
    float deltaLuma = CAMERA_OBSCURA_Luma(delta);
    float3 heat = CAMERA_OBSCURA_DebugHeat(saturate(deltaLuma * 8.0));
    return saturate(CAMERA_OBSCURA_DebugSourceAnchor(source) + heat * saturate(deltaLuma * 6.0));
}

float3 CAMERA_OBSCURA_DebugProviderBalance(
    float3 source,
    CAMERA_OBSCURA_Contribution ddaContribution,
    CAMERA_OBSCURA_Contribution marchContribution)
{
    float ddaWeight = ddaContribution.weight * ddaContribution.valid;
    float marchWeight = marchContribution.weight * marchContribution.valid;
    float totalWeight = max(ddaWeight + marchWeight, 0.000001);
    float ddaShare = saturate(ddaWeight / totalWeight);
    float marchShare = saturate(marchWeight / totalWeight);
    float active = saturate(ddaContribution.valid + marchContribution.valid);

    float ddaDominance = smoothstep(0.12, 0.55, ddaShare - marchShare);
    float marchDominance = smoothstep(0.12, 0.55, marchShare - ddaShare);
    float balanced = saturate(1.0 - max(ddaDominance, marchDominance));
    float marchRisk = marchShare *
        smoothstep(0.05, 0.35, marchContribution.weight - ddaContribution.weight) *
        marchContribution.valid;

    float3 categorical = saturate(
        float3(0.120, 0.550, 1.000) * ddaDominance +
        float3(1.000, 0.420, 0.140) * marchDominance +
        float3(0.260, 0.620, 0.360) * balanced);
    float3 balanceSignal = lerp(
        categorical,
        float3(1.000, 0.050, 0.050),
        saturate(marchRisk));

    return saturate(lerp(
        CAMERA_OBSCURA_DebugSourceAnchor(source),
        balanceSignal,
        0.30 + active * 0.50));
}

float3 CAMERA_OBSCURA_DebugAgreement(CAMERA_OBSCURA_DualHit dual)
{
    float bothHit = min(dual.dda_hit, dual.march_hit);
    float anyHit = max(dual.dda_hit, dual.march_hit);
    float hitSplit = saturate(abs(dual.dda_hit - dual.march_hit));
    float agreement = saturate(min(
        dual.uv_agreement,
        min(dual.depth_agreement, dual.distance_agreement)));
    float confidenceSplit = saturate(abs(dual.dda_confidence - dual.march_confidence));
    float confidenceMean = saturate((dual.dda_confidence + dual.march_confidence) * 0.5);
    float strongAgreement = bothHit * agreement * confidenceMean;
    float weakAgreement = bothHit * agreement * (1.0 - confidenceMean);
    float conflict = saturate(max(dual.conflict, hitSplit) * anyHit);
    float noEvidence = saturate(1.0 - anyHit);

    return saturate(
        float3(1.000, 0.080, 0.030) * conflict +
        float3(0.080, 0.700, 0.180) * strongAgreement +
        float3(0.720, 0.600, 0.080) * weakAgreement +
        float3(0.080, 0.180, 0.850) * confidenceSplit * anyHit +
        float3(0.120, 0.120, 0.160) * noEvidence);
}

float3 CAMERA_OBSCURA_DebugAgreementView(
    float3 source,
    CAMERA_OBSCURA_DualHit dual)
{
    float bothHit = min(dual.dda_hit, dual.march_hit);
    float anyHit = max(dual.dda_hit, dual.march_hit);
    float hitSplit = saturate(abs(dual.dda_hit - dual.march_hit));
    float agreement = saturate(min(
        dual.uv_agreement,
        min(dual.depth_agreement, dual.distance_agreement)));
    float confidenceSplit = saturate(abs(dual.dda_confidence - dual.march_confidence));
    float confidenceMean = saturate((dual.dda_confidence + dual.march_confidence) * 0.5);
    float strongAgreement = bothHit * agreement * confidenceMean;
    float weakAgreement = bothHit * agreement * (1.0 - confidenceMean);
    float conflict = saturate(max(dual.conflict, hitSplit) * anyHit);
    float noEvidence = saturate(1.0 - anyHit);
    float broadAgreement = saturate(
        strongAgreement +
        weakAgreement * CAMERA_OBSCURA_DEBUG_AGREEMENT_WEAK_WEIGHT);
    float agreementDisplay = smoothstep(
        CAMERA_OBSCURA_DEBUG_AGREEMENT_DISPLAY_MIN,
        CAMERA_OBSCURA_DEBUG_AGREEMENT_DISPLAY_MAX,
        broadAgreement);
    float weakDisplay = smoothstep(
        CAMERA_OBSCURA_DEBUG_AGREEMENT_DISPLAY_MIN,
        CAMERA_OBSCURA_DEBUG_AGREEMENT_DISPLAY_MAX,
        weakAgreement);
    float issueStrength = saturate(max(conflict, confidenceSplit * anyHit));

    float3 agreementTint = saturate(
        source +
        float3(
            0.000,
            CAMERA_OBSCURA_DEBUG_AGREEMENT_GREEN_G,
            CAMERA_OBSCURA_DEBUG_AGREEMENT_GREEN_B) * agreementDisplay +
        float3(
            CAMERA_OBSCURA_DEBUG_AGREEMENT_WEAK_R,
            CAMERA_OBSCURA_DEBUG_AGREEMENT_WEAK_G,
            0.000) * weakDisplay);
    float3 issueSignal = saturate(
        source * 0.18 +
        float3(1.000, 0.060, 0.030) * conflict +
        float3(0.080, 0.200, 1.000) * confidenceSplit * anyHit);
    float3 noEvidenceSignal = saturate(source * 0.72 + float3(0.020, 0.020, 0.030));
    float3 issueView = lerp(
        agreementTint,
        issueSignal,
        issueStrength * CAMERA_OBSCURA_DEBUG_AGREEMENT_ISSUE_BLEND);
    return saturate(lerp(
        issueView,
        noEvidenceSignal,
        noEvidence * CAMERA_OBSCURA_DEBUG_AGREEMENT_NO_EVIDENCE_BLEND));
}

float3 CAMERA_OBSCURA_DebugView(
    float view,
    float3 source,
    float3 composite,
    CAMERA_OBSCURA_Hit dda,
    CAMERA_OBSCURA_Hit march,
    CAMERA_OBSCURA_DualHit dual,
    CAMERA_OBSCURA_Contribution ddaContribution,
    CAMERA_OBSCURA_Contribution marchContribution)
{
    if (view < 0.5)
    {
        return composite;
    }

    if (view < 1.5)
    {
        return CAMERA_OBSCURA_DebugOverlay(source, CAMERA_OBSCURA_DebugHit(dda));
    }

    if (view < 2.5)
    {
        return CAMERA_OBSCURA_DebugOverlay(source, CAMERA_OBSCURA_DebugHit(march));
    }

    if (view < 3.5)
    {
        return CAMERA_OBSCURA_DebugAgreementView(source, dual);
    }

    if (view < 4.5)
    {
        return CAMERA_OBSCURA_DebugContributionView(source, ddaContribution);
    }

    if (view < 5.5)
    {
        return CAMERA_OBSCURA_DebugContributionView(source, marchContribution);
    }

    if (view < 6.5)
    {
        return CAMERA_OBSCURA_DebugOverlay(
            source,
            saturate(0.5 * CAMERA_OBSCURA_DebugReasonColor(dda.reason) +
                0.5 * CAMERA_OBSCURA_DebugReasonColor(march.reason)));
    }

    if (view < 7.5)
    {
        return CAMERA_OBSCURA_DebugCompositeDelta(source, composite);
    }

    if (view < 8.5)
    {
        return CAMERA_OBSCURA_DebugProviderBalance(
            source,
            ddaContribution,
            marchContribution);
    }

    return source;
}

#endif // CAMERA_OBSCURA_ATOMIC_DEBUG_FXH
