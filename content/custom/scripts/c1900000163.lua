-- Exeggcute
-- If "Sunny Day" is on the field, you can Special Summon this card (from your hand) in Defense Position.
-- You can only Special Summon "Exeggcute" once per turn this way.
-- If this card is Summoned while "Sunny Day" is on the field: You can target 1 Spell/Trap in your GY that states
-- "Pokemon" in its text; add it to your hand.
local s,id=GetID()
function s.initial_effect(c)
	-- Special Summon from the hand (built-in, like Cyber Dragon)
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_FIELD)
	e1:SetCode(EFFECT_SPSUMMON_PROC)
	e1:SetProperty(EFFECT_FLAG_UNCOPYABLE+EFFECT_FLAG_SPSUM_PARAM)
	e1:SetRange(LOCATION_HAND)
	e1:SetTargetRange(POS_FACEUP_DEFENSE,0)       -- in Defense Position
	e1:SetCountLimit(1,{id,10},EFFECT_COUNT_CODE_OATH)
	e1:SetCondition(function(e,c)
		if c==nil then return true end
		return Pokemon.IsOnField(CARD_SUNNY_DAY) and Duel.GetLocationCount(c:GetControler(),LOCATION_MZONE)>0
	end)
	c:RegisterEffect(e1)
	-- Get back a "Pokemon" Spell/Trap
	local e2=Effect.CreateEffect(c)
	e2:SetDescription(aux.Stringid(id,0))
	e2:SetCategory(CATEGORY_TOHAND)
	e2:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_TRIGGER_O)
	e2:SetProperty(EFFECT_FLAG_CARD_TARGET+EFFECT_FLAG_DELAY)
	e2:SetCode(EVENT_SUMMON_SUCCESS)
	e2:SetCondition(function() return Pokemon.IsOnField(CARD_SUNNY_DAY) end)
	e2:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk,chkc)
		if chkc then return chkc:IsLocation(LOCATION_GRAVE) and chkc:IsControler(tp) and s.filter(chkc) end
		if chk==0 then return Duel.IsExistingTarget(s.filter,tp,LOCATION_GRAVE,0,1,nil) end
		Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_ATOHAND)
		local g=Duel.SelectTarget(tp,s.filter,tp,LOCATION_GRAVE,0,1,1,nil)
		Duel.SetOperationInfo(0,CATEGORY_TOHAND,g,1,0,0)
	end)
	e2:SetOperation(function(e,tp)
		local tc=Duel.GetFirstTarget()
		if tc and tc:IsRelateToEffect(e) then Duel.SendtoHand(tc,nil,REASON_EFFECT) Duel.ConfirmCards(1-tp,tc) end
	end)
	c:RegisterEffect(e2)
	local e3=e2:Clone() e3:SetCode(EVENT_SPSUMMON_SUCCESS) c:RegisterEffect(e3)
	local e4=e2:Clone() e4:SetCode(EVENT_FLIP_SUMMON_SUCCESS) c:RegisterEffect(e4)
end
s.listed_names={CARD_SUNNY_DAY}
function s.filter(c) return Pokemon.MentionsPokemon(c) and c:IsAbleToHand() end
