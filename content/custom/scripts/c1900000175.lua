-- Koffing
-- Once per turn: You can target 1 monster your opponent controls; toss a coin and call it, and if you call it
-- right, place 1 Poison Counter on it.
-- You can destroy this card; inflict 800 damage to your opponent. You can only activate this effect of "Koffing"
-- once per turn.
local s,id=GetID()
function s.initial_effect(c)
	Pokemon.AddCoinPoison(c,1)                 -- Prompt 2
	local e1=Effect.CreateEffect(c)
	e1:SetDescription(aux.Stringid(id,0))
	e1:SetCategory(CATEGORY_DAMAGE)
	e1:SetType(EFFECT_TYPE_IGNITION)
	e1:SetRange(LOCATION_MZONE)
	e1:SetCountLimit(1,id)
	e1:SetCost(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return e:GetHandler():IsDestructable() end
		Duel.Destroy(e:GetHandler(),REASON_COST)
	end)
	e1:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return true end
		Duel.SetOperationInfo(0,CATEGORY_DAMAGE,nil,0,1-tp,800)
	end)
	e1:SetOperation(function(e,tp) Duel.Damage(1-tp,800,REASON_EFFECT) end)
	c:RegisterEffect(e1)
end
s.toss_coin=true
