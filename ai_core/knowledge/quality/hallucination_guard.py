from ai_core.knowledge.quality.confidence_model import FirewallDecision


class HallucinationGuard:
    def can_generate_answer(self, decision: FirewallDecision) -> bool:
        return decision.approved and not decision.trigger_unknown_mode and not decision.request_more_info

    def must_trigger_unknown(self, decision: FirewallDecision) -> bool:
        return decision.trigger_unknown_mode or decision.rejected

    def must_request_more_info(self, decision: FirewallDecision) -> bool:
        return decision.request_more_info
