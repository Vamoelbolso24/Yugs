-- Stealth Rocks (Continuous Spell)
-- You can only control 1 "Stealth Rocks".
-- If your opponent Normal or Special Summons a monster(s): Inflict 300 damage to your opponent, or 600 damage
-- instead if they Summoned a FIRE or WIND monster.
local s,id=GetID()
function s.initial_effect(c)
	c:SetUniqueOnField(1,0,id)                 -- only 1 on your field
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_FREE_CHAIN)
	c:RegisterEffect(e1)
	local e2=Effect.CreateEffect(c)
	e2:SetDescription(aux.Stringid(id,0))
	e2:SetCategory(CATEGORY_DAMAGE)
	e2:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_TRIGGER_F)
	e2:SetCode(EVENT_SUMMON_SUCCESS)
	e2:SetRange(LOCATION_SZONE)
	e2:SetProperty(EFFECT_FLAG_DELAY)
	e2:SetCondition(function(e,tp,eg) return eg:IsExists(Card.IsSummonPlayer,1,nil,1-tp) end)
	e2:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return true end
		-- decide the amount now, from the monsters that were Summoned
		local big=eg:IsExists(function(tc) return tc:IsSummonPlayer(1-tp) and tc:IsAttribute(ATTRIBUTE_FIRE|ATTRIBUTE_WIND) end,1,nil)
		e:SetLabel(big and 600 or 300)
		Duel.SetOperationInfo(0,CATEGORY_DAMAGE,nil,0,1-tp,e:GetLabel())
	end)
	e2:SetOperation(function(e,tp)
		if e:GetHandler():IsRelateToEffect(e) then Duel.Damage(1-tp,e:GetLabel(),REASON_EFFECT) end
	end)
	c:RegisterEffect(e2)
	local e3=e2:Clone()
	e3:SetCode(EVENT_SPSUMMON_SUCCESS)
	c:RegisterEffect(e3)
end
