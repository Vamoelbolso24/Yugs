-- Electrode
-- Evolution Summon from "Voltorb" (hard once per turn).
-- Once per turn (Quick Effect): You can target 1 monster your opponent controls; it cannot activate its effects
-- until the end of this turn. Your opponent cannot activate cards or effects in response to this effect's activation.
-- (Quick Effect): You can destroy this card; destroy 1 monster your opponent controls with 2500 or less DEF, and
-- inflict 1000 damage to your opponent.
-- PATTERN: "can't respond to this activation" = Duel.SetChainLimit in the target function.
local s,id=GetID()
function s.initial_effect(c)
	Pokemon.AddEvolutionSummon(c,1900000159)   -- from Voltorb
	-- Lock a monster's effects
	local e1=Effect.CreateEffect(c)
	e1:SetDescription(aux.Stringid(id,0))
	e1:SetType(EFFECT_TYPE_QUICK_O)
	e1:SetCode(EVENT_FREE_CHAIN)
	e1:SetRange(LOCATION_MZONE)
	e1:SetProperty(EFFECT_FLAG_CARD_TARGET)
	e1:SetHintTiming(0,TIMINGS_CHECK_MONSTER)
	e1:SetCountLimit(1,id)
	e1:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk,chkc)
		if chkc then return chkc:IsLocation(LOCATION_MZONE) and chkc:IsControler(1-tp) end
		if chk==0 then return Duel.IsExistingTarget(nil,tp,0,LOCATION_MZONE,1,nil) end
		Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_TARGET)
		Duel.SelectTarget(tp,nil,tp,0,LOCATION_MZONE,1,1,nil)
		Duel.SetChainLimit(function(e,rp,tp) return tp==rp end)   -- only the activating player may respond
	end)
	e1:SetOperation(function(e,tp)
		local tc=Duel.GetFirstTarget()
		if not (tc and tc:IsRelateToEffect(e)) then return end
		local e2=Effect.CreateEffect(e:GetHandler())
		e2:SetType(EFFECT_TYPE_SINGLE)
		e2:SetCode(EFFECT_CANNOT_TRIGGER)
		e2:SetReset(RESETS_STANDARD_PHASE_END)
		tc:RegisterEffect(e2)
	end)
	c:RegisterEffect(e1)
	-- Self-Destruct
	local e3=Effect.CreateEffect(c)
	e3:SetDescription(aux.Stringid(id,1))
	e3:SetCategory(CATEGORY_DESTROY+CATEGORY_DAMAGE)
	e3:SetType(EFFECT_TYPE_QUICK_O)
	e3:SetCode(EVENT_FREE_CHAIN)
	e3:SetRange(LOCATION_MZONE)
	e3:SetHintTiming(0,TIMINGS_CHECK_MONSTER|TIMING_END_PHASE)
	e3:SetCost(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return e:GetHandler():IsDestructable() end
		Duel.Destroy(e:GetHandler(),REASON_COST)
	end)
	e3:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return true end
		Duel.SetOperationInfo(0,CATEGORY_DAMAGE,nil,0,1-tp,1000)
	end)
	e3:SetOperation(function(e,tp)
		local g=Duel.GetMatchingGroup(s.filter,tp,0,LOCATION_MZONE,nil)
		if #g>0 then
			Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_DESTROY)
			local sg=g:Select(tp,1,1,nil)
			Duel.HintSelection(sg)
			Duel.Destroy(sg,REASON_EFFECT)
		end
		Duel.Damage(1-tp,1000,REASON_EFFECT)
	end)
	c:RegisterEffect(e3)
end
s.listed_names={1900000159}
function s.filter(c) return c:IsFaceup() and c:IsDefenseBelow(2500) end
