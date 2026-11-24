-- Moltres (Ritual)
-- You can Ritual Summon this card with "Legendary Bird Trio".
-- If this card is Ritual Summoned: Inflict 1500 damage to your opponent. You can only use this effect of "Moltres"
-- once per turn.
-- If a card(s) is sent to your opponent's GY: Inflict 300 damage to your opponent for each of those cards.
local s,id=GetID()
s.listed_names={1900000222}
function s.initial_effect(c)
	c:EnableReviveLimit()
	local e1=Effect.CreateEffect(c)
	e1:SetDescription(aux.Stringid(id,0))
	e1:SetCategory(CATEGORY_DAMAGE)
	e1:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_TRIGGER_F)
	e1:SetCode(EVENT_SPSUMMON_SUCCESS)
	e1:SetCountLimit(1,id)
	e1:SetCondition(function(e) return e:GetHandler():IsRitualSummoned() end)
	e1:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return true end
		Duel.SetTargetPlayer(1-tp) Duel.SetTargetParam(1500)
		Duel.SetOperationInfo(0,CATEGORY_DAMAGE,nil,0,1-tp,1500)
	end)
	e1:SetOperation(function(e)
		local p,d=Duel.GetChainInfo(0,CHAININFO_TARGET_PLAYER,CHAININFO_TARGET_PARAM)
		Duel.Damage(p,d,REASON_EFFECT)
	end)
	c:RegisterEffect(e1)
	-- 300 per card sent to the opponent's GY (no chain, like a burn rule)
	local e2=Effect.CreateEffect(c)
	e2:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS)
	e2:SetCode(EVENT_TO_GRAVE)
	e2:SetRange(LOCATION_MZONE)
	e2:SetCondition(function(e,tp,eg) return e:GetHandler():IsFaceup() and eg:IsExists(Card.IsControler,1,nil,1-tp) end)
	e2:SetOperation(function(e,tp,eg)
		local ct=eg:FilterCount(Card.IsControler,nil,1-tp)
		Duel.Hint(HINT_CARD,0,id)
		Duel.Damage(1-tp,ct*300,REASON_EFFECT)
	end)
	c:RegisterEffect(e2)
end
