from ai_core.education.owner_profiles import LearningHistoryItem, OwnerKnowledgeProfile


class LearningBuilder:
    def record_topic(
        self,
        profile: OwnerKnowledgeProfile,
        topic: str,
        confidence: str,
    ) -> OwnerKnowledgeProfile:
        updated = profile.model_copy(deep=True)
        updated.learning_history.append(
            LearningHistoryItem(topic=topic, confidence=confidence)
        )
        return updated
