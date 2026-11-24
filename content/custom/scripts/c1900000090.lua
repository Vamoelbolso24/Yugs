-- Gym Leader - Lt Surge (Continuous Spell)
-- You can only control 1 "Gym Leader" card.
-- When this card is activated: You can add 1 Level 5 or higher LIGHT Pokemon monster from your Deck to your hand.
-- If a LIGHT Pokemon monster is Summoned by its own effect, or by the effect of "Thunder Stone": Draw 1 card.
-- You can only activate this effect of "Gym Leader - Lt Surge" twice per turn.
-- "Summoned by its own effect" = its Evolution Summon (or any way it Summons itself, like Golbat).
local s,id=GetID()
function s.initial_effect(c)
	Pokemon.AddGymLeader(c,nil,nil,function(e,tp)
		Pokemon.ActivationSearch(e,tp,s.thfilter,aux.Stringid(id,0))   -- Prompt 1
	end)
	local e2=Effect.CreateEffect(c)
	e2:SetDescription(aux.Stringid(id,1))
	e2:SetCategory(CATEGORY_DRAW)
	e2:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_TRIGGER_F)
	e2:SetCode(EVENT_SPSUMMON_SUCCESS)
	e2:SetRange(LOCATION_SZONE)
	e2:SetProperty(EFFECT_FLAG_DELAY)
	e2:SetCountLimit(2,id)                       -- twice per turn
	e2:SetCondition(function(e,tp,eg) return eg:IsExists(s.cfilter,1,nil,tp) end)
	e2:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return true end
		Duel.SetOperationInfo(0,CATEGORY_DRAW,nil,0,tp,1)
	end)
	e2:SetOperation(function(e,tp)
		if e:GetHandler():IsRelateToEffect(e) then Duel.Draw(tp,1,REASON_EFFECT) end
	end)
	c:RegisterEffect(e2)
end
s.listed_names={CARD_THUNDER_STONE}
function s.thfilter(c) return c:IsSetCard(SET_POKEMON) and c:IsAttribute(ATTRIBUTE_LIGHT) and c:IsLevelAbove(5) end
-- a LIGHT Pokemon you Summoned, by its own effect or by Thunder Stone
function s.cfilter(c,tp)
	if not (c:IsFaceup() and c:IsControler(tp) and c:IsSetCard(SET_POKEMON) and c:IsAttribute(ATTRIBUTE_LIGHT)) then return false end
	local re=c:GetReasonEffect()
	if not re then return false end
	local h=re:GetHandler()
	return h==c or h:IsCode(CARD_THUNDER_STONE)
end
