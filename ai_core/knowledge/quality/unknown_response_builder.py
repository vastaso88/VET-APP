from ai_core.knowledge.quality.confidence_model import FirewallDecision, UnknownResponse


class UnknownResponseBuilder:
    def build(self, decision: FirewallDecision) -> UnknownResponse:
        limitations = list(decision.reasons)
        if decision.request_more_info:
            answer = (
                "Per rispondere in modo prudente mi manca ancora qualche informazione clinicamente "
                "rilevante. Posso continuare con poche domande mirate prima di darti una spiegazione."
            )
            recommended_action = "Condividi i dettagli mancanti oppure contatta il veterinario se il quadro peggiora."
        else:
            answer = (
                "Non ho evidenza sufficientemente affidabile e coerente per darti una risposta educativa "
                "sicura su questo punto senza rischiare di semplificare troppo."
            )
            recommended_action = (
                "Monitora il pet da vicino e consulta il veterinario se i sintomi persistono, peggiorano o "
                "coinvolgono energia, appetito, respiro o dolore."
            )
        return UnknownResponse(
            answer=answer,
            limitations=limitations,
            recommended_action=recommended_action,
        )
