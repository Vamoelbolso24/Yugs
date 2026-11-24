-- Ninetales
-- Evolution Summon from "Vulpix" (hard once per turn).
-- Once per turn: You can place a Burn Counter on a monster your opponent controls.
-- During either player's turn, when a card or effect is activated: You can remove 1 Burn Counter from
-- the field; negate the activation, and if you do, destroy that card.
-- You can only activate this effect of "Ninetales" once per turn.
-- PATTERN: "when a card or effect is activated: negate" = QUICK_O on EVENT_CHAINING,
-- Duel.NegateActivation(ev). The Burn Counter is removed as a cost.
local s,id=GetID()
function s.initial_effect(c)
	Pokemon.AddEvolutionSummon(c,1900000052)   -- from Vulpix
	Pokemon.AddBurnCounter(c,0)                -- Prompt 1

	local e1=Effect.CreateEffect(c)
	e1:SetDescription(aux.Stringid(id,1))       -- Prompt 2
	e1:SetCategory(CATEGORY_NEGATE+CATEGORY_DESTROY)
	e1:SetType(EFFECT_TYPE_QUICK_O)
	e1:SetCode(EVENT_CHAINING)
	e1:SetProperty(EFFECT_FLAG_DAMAGE_STEP+EFFECT_FLAG_DAMAGE_CAL)
	e1:SetRange(LOCATION_MZONE)
	e1:SetCountLimit(1,id)
	e1:SetCondition(function(e,tp,eg,ep,ev,re,r,rp)
		return not e:GetHandler():IsStatus(STATUS_BATTLE_DESTROYED) and Duel.IsChainNegatable(ev)
	end)
	e1:SetCost(function(e,tp,eg,ep,ev,re,r,rp,chk)
		-- any Burn Counter on the field (1,1 = your side and your opponent's side)
		if chk==0 then return Duel.IsCanRemoveCounter(tp,1,1,COUNTER_BURN,1,REASON_COST) end
		Duel.RemoveCounter(tp,1,1,COUNTER_BURN,1,REASON_COST)
	end)
	e1:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return true end
		Duel.SetOperationInfo(0,CATEGORY_NEGATE,eg,1,0,0)
		if re:GetHandler():IsDestructable() and re:GetHandler():IsRelateToEffect(re) then
			Duel.SetOperationInfo(0,CATEGORY_DESTROY,eg,1,0,0)
		end
	end)
	e1:SetOperation(function(e,tp,eg,ep,ev,re,r,rp)
		if Duel.NegateActivation(ev) and re:GetHandler():IsRelateToEffect(re) then
			Duel.Destroy(eg,REASON_EFFECT)
		end
	end)
	c:RegisterEffect(e1)
end
s.listed_names={1900000052}
