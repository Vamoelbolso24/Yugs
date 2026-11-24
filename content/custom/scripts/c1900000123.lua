-- Spikes (Continuous Spell)
-- When this card is activated: You can add 1 "Spikes" from your Deck to your hand. You cannot conduct your
-- Battle Phase the turn you activate this card.
-- If your opponent Normal or Special Summons a monster(s), immediately inflict 300 damage to them for each
-- monster Summoned. You can only activate 1 "Spikes" per turn.
-- PATTERN: "immediately" = a continuous effect (EFFECT_TYPE_CONTINUOUS): it happens right away, no chain.
-- "You cannot conduct your Battle Phase the turn you activate this card" = check ACTIVITY_BATTLE_PHASE in the
-- cost, then EFFECT_CANNOT_BP for the rest of the turn.
local s,id=GetID()
function s.initial_effect(c)
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_FREE_CHAIN)
	e1:SetCountLimit(1,id,EFFECT_COUNT_CODE_OATH)
	e1:SetCost(s.nobpcost)
	e1:SetOperation(function(e,tp)
		Pokemon.ActivationSearch(e,tp,function(tc) return tc:IsCode(id) end,aux.Stringid(id,0))
	end)
	c:RegisterEffect(e1)
	-- 300 per monster the opponent Summons
	local e2=Effect.CreateEffect(c)
	e2:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS)
	e2:SetCode(EVENT_SUMMON_SUCCESS)
	e2:SetRange(LOCATION_SZONE)
	e2:SetOperation(function(e,tp,eg)
		local n=eg:FilterCount(Card.IsSummonPlayer,nil,1-tp)
		if n>0 then
			Duel.Hint(HINT_CARD,0,id)
			Duel.Damage(1-tp,300*n,REASON_EFFECT)
		end
	end)
	c:RegisterEffect(e2)
	local e3=e2:Clone()
	e3:SetCode(EVENT_SPSUMMON_SUCCESS)
	c:RegisterEffect(e3)
end
s.listed_names={id}
function s.nobpcost(e,tp,eg,ep,ev,re,r,rp,chk)
	if chk==0 then return Duel.GetActivityCount(tp,ACTIVITY_BATTLE_PHASE)==0 end
	local e1=Effect.CreateEffect(e:GetHandler())
	e1:SetType(EFFECT_TYPE_FIELD)
	e1:SetProperty(EFFECT_FLAG_PLAYER_TARGET+EFFECT_FLAG_OATH)
	e1:SetCode(EFFECT_CANNOT_BP)
	e1:SetTargetRange(1,0)
	e1:SetReset(RESET_PHASE|PHASE_END)
	Duel.RegisterEffect(e1,tp)
end
