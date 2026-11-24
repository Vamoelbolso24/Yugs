-- Rhydon
-- Evolution Summon from "Rhyhorn" (hard once per turn).
-- Gains 100 ATK for each LIGHT monster your opponent controls.
-- If this card attacks, it cannot declare an attack during your next Battle Phase.
-- Once per turn, when a LIGHT monster's effect is activated (Quick Effect): You can discard 1 card; negate the
-- activation, and if you do, destroy it.
local s,id=GetID()
function s.initial_effect(c)
	Pokemon.AddEvolutionSummon(c,1900000177)   -- from Rhyhorn
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_SINGLE)
	e1:SetProperty(EFFECT_FLAG_SINGLE_RANGE)
	e1:SetRange(LOCATION_MZONE)
	e1:SetCode(EFFECT_UPDATE_ATTACK)
	e1:SetValue(function(e) return 100*Duel.GetMatchingGroupCount(aux.FaceupFilter(Card.IsAttribute,ATTRIBUTE_LIGHT),e:GetHandlerPlayer(),0,LOCATION_MZONE,nil) end)
	c:RegisterEffect(e1)
	-- After attacking: no attack during your next Battle Phase
	local e2=Effect.CreateEffect(c)
	e2:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_CONTINUOUS)
	e2:SetCode(EVENT_ATTACK_ANNOUNCE)
	e2:SetOperation(function(e)
		local c=e:GetHandler()
		local e3=Effect.CreateEffect(c)
		e3:SetType(EFFECT_TYPE_SINGLE)
		e3:SetCode(EFFECT_CANNOT_ATTACK_ANNOUNCE)
		e3:SetCondition(function(ef) return Duel.GetTurnCount()~=ef:GetLabel() end)   -- not this turn, the next one
		e3:SetLabel(Duel.GetTurnCount())
		e3:SetReset(RESET_EVENT|RESETS_STANDARD|RESET_PHASE|PHASE_END|RESET_SELF_TURN,2)
		c:RegisterEffect(e3)
	end)
	c:RegisterEffect(e2)
	-- Negate a LIGHT monster's effect
	local e4=Effect.CreateEffect(c)
	e4:SetDescription(aux.Stringid(id,0))
	e4:SetCategory(CATEGORY_NEGATE+CATEGORY_DESTROY)
	e4:SetType(EFFECT_TYPE_QUICK_O)
	e4:SetCode(EVENT_CHAINING)
	e4:SetRange(LOCATION_MZONE)
	e4:SetProperty(EFFECT_FLAG_DAMAGE_STEP+EFFECT_FLAG_DAMAGE_CAL)
	e4:SetCountLimit(1)
	e4:SetCondition(function(e,tp,eg,ep,ev,re,r,rp)
		return re:IsMonsterEffect() and re:GetHandler():IsAttribute(ATTRIBUTE_LIGHT) and re:GetHandler()~=e:GetHandler()
			and Duel.IsChainNegatable(ev)
	end)
	e4:SetCost(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return Duel.IsExistingMatchingCard(Card.IsDiscardable,tp,LOCATION_HAND,0,1,nil) end
		Duel.DiscardHand(tp,Card.IsDiscardable,1,1,REASON_COST|REASON_DISCARD)
	end)
	e4:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return true end
		Duel.SetOperationInfo(0,CATEGORY_NEGATE,eg,1,0,0)
		if re:GetHandler():IsDestructable() and re:GetHandler():IsRelateToEffect(re) then Duel.SetOperationInfo(0,CATEGORY_DESTROY,eg,1,0,0) end
	end)
	e4:SetOperation(function(e,tp,eg,ep,ev,re,r,rp)
		if Duel.NegateActivation(ev) and re:GetHandler():IsRelateToEffect(re) then Duel.Destroy(eg,REASON_EFFECT) end
	end)
	c:RegisterEffect(e4)
end
s.listed_names={1900000177}
