-- Frenzy Plant (Normal Spell)
-- Target 1 "Venusaur" you control; it gains 700 ATK until the end of this turn, also it gains this effect
-- until the End Phase:
-- * If this card destroys a monster by battle: You can target up to 3 Level 5 or lower Plant monsters in
--   your GY and/or banishment; return them to the hand.
-- PATTERN: give another card a temporary effect = create the effect, then tc:RegisterEffect(...) with a Reset.
local s,id=GetID()
function s.initial_effect(c)
	local e1=Effect.CreateEffect(c)
	e1:SetCategory(CATEGORY_ATKCHANGE)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_FREE_CHAIN)
	e1:SetProperty(EFFECT_FLAG_CARD_TARGET)
	e1:SetTarget(s.target)
	e1:SetOperation(s.activate)
	c:RegisterEffect(e1)
end
s.listed_names={1900000004}   -- Venusaur

function s.vfilter(c)
	return c:IsFaceup() and c:IsCode(1900000004)
end
function s.target(e,tp,eg,ep,ev,re,r,rp,chk,chkc)
	if chkc then return chkc:IsLocation(LOCATION_MZONE) and chkc:IsControler(tp) and s.vfilter(chkc) end
	if chk==0 then return Duel.IsExistingTarget(s.vfilter,tp,LOCATION_MZONE,0,1,nil) end
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_FACEUP)
	Duel.SelectTarget(tp,s.vfilter,tp,LOCATION_MZONE,0,1,1,nil)
end
function s.activate(e,tp,eg,ep,ev,re,r,rp)
	local c=e:GetHandler()
	local tc=Duel.GetFirstTarget()
	if not (tc and tc:IsRelateToEffect(e) and tc:IsFaceup()) then return end
	-- +700 ATK until the end of this turn
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_SINGLE)
	e1:SetCode(EFFECT_UPDATE_ATTACK)
	e1:SetValue(700)
	e1:SetReset(RESETS_STANDARD_PHASE_END)     -- goes away at the End Phase (or if the card leaves the field)
	tc:RegisterEffect(e1)
	-- The granted battle effect, also until the End Phase
	local e2=Effect.CreateEffect(c)
	e2:SetDescription(aux.Stringid(id,0))      -- Prompt 1
	e2:SetCategory(CATEGORY_TOHAND)
	e2:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_TRIGGER_O)
	e2:SetCode(EVENT_BATTLE_DESTROYING)
	e2:SetProperty(EFFECT_FLAG_CARD_TARGET+EFFECT_FLAG_CLIENT_HINT)   -- CLIENT_HINT: shows the player it has this effect
	e2:SetCondition(aux.bdcon)
	e2:SetTarget(s.thtg)
	e2:SetOperation(s.thop)
	e2:SetReset(RESETS_STANDARD_PHASE_END)
	tc:RegisterEffect(e2)
end

-- Level 5 or lower Plant monsters in the GY, or face-up among banished cards, that can go to the hand.
function s.thfilter(c)
	return c:IsMonster() and c:IsRace(RACE_PLANT) and c:IsLevelBelow(5) and c:IsAbleToHand()
		and (c:IsLocation(LOCATION_GRAVE) or c:IsFaceup())
end
function s.thtg(e,tp,eg,ep,ev,re,r,rp,chk,chkc)
	if chkc then return chkc:IsControler(tp) and chkc:IsLocation(LOCATION_GRAVE|LOCATION_REMOVED) and s.thfilter(chkc) end
	if chk==0 then return Duel.IsExistingTarget(s.thfilter,tp,LOCATION_GRAVE|LOCATION_REMOVED,0,1,nil) end
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_ATOHAND)
	local g=Duel.SelectTarget(tp,s.thfilter,tp,LOCATION_GRAVE|LOCATION_REMOVED,0,1,3,nil)   -- 1 to 3 targets
	Duel.SetOperationInfo(0,CATEGORY_TOHAND,g,#g,0,0)
end
function s.thop(e,tp,eg,ep,ev,re,r,rp)
	local g=Duel.GetTargetCards(e)            -- the targets that are still valid
	if #g>0 then
		Duel.SendtoHand(g,nil,REASON_EFFECT)
		Duel.ConfirmCards(1-tp,g)                -- show the opponent which cards went to the hand
	end
end
