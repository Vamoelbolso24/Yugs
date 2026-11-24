-- Ditto
-- Cannot be Special Summoned from the Deck.
-- When this card is Normal or Special Summoned: Target 1 monster your opponent controls; this card's name,
-- Attribute, Type, Level and original ATK become that monster's, also this card gains that monster's effects.
-- (It keeps them while it stays face-up on the field.)
local s,id=GetID()
function s.initial_effect(c)
	local e0=Effect.CreateEffect(c)
	e0:SetType(EFFECT_TYPE_SINGLE)
	e0:SetProperty(EFFECT_FLAG_CANNOT_DISABLE+EFFECT_FLAG_UNCOPYABLE)
	e0:SetCode(EFFECT_SPSUMMON_CONDITION)
	e0:SetValue(function(e) return not e:GetHandler():IsLocation(LOCATION_DECK) end)
	c:RegisterEffect(e0)
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_TRIGGER_F)
	e1:SetProperty(EFFECT_FLAG_CARD_TARGET)
	e1:SetCode(EVENT_SUMMON_SUCCESS)
	e1:SetTarget(s.target)
	e1:SetOperation(s.operation)
	c:RegisterEffect(e1)
	local e2=e1:Clone() e2:SetCode(EVENT_SPSUMMON_SUCCESS) c:RegisterEffect(e2)
end
function s.target(e,tp,eg,ep,ev,re,r,rp,chk,chkc)
	if chkc then return chkc:IsLocation(LOCATION_MZONE) and chkc:IsControler(1-tp) and chkc:IsFaceup() end
	if chk==0 then return true end   -- mandatory: nothing happens if there is no target
	if Duel.IsExistingTarget(Card.IsFaceup,tp,0,LOCATION_MZONE,1,nil) then
		Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_TARGET)
		Duel.SelectTarget(tp,Card.IsFaceup,tp,0,LOCATION_MZONE,1,1,nil)
	end
end
function s.operation(e,tp)
	local c=e:GetHandler()
	local tc=Duel.GetFirstTarget()
	if not (tc and tc:IsRelateToEffect(e) and tc:IsFaceup() and c:IsRelateToEffect(e) and c:IsFaceup()) then return end
	local code=tc:GetCode()
	local function set(ecode,val)
		local ef=Effect.CreateEffect(c)
		ef:SetType(EFFECT_TYPE_SINGLE)
		ef:SetCode(ecode)
		ef:SetValue(val)
		ef:SetReset(RESET_EVENT|RESETS_STANDARD)
		c:RegisterEffect(ef)
	end
	set(EFFECT_CHANGE_CODE,code)
	set(EFFECT_CHANGE_ATTRIBUTE,tc:GetAttribute())
	set(EFFECT_CHANGE_RACE,tc:GetRace())
	if tc:HasLevel() then set(EFFECT_CHANGE_LEVEL,tc:GetLevel()) end
	set(EFFECT_SET_BASE_ATTACK,tc:GetBaseAttack())
	if tc:IsType(TYPE_EFFECT) then c:CopyEffect(code,RESET_EVENT|RESETS_STANDARD,1) end
end
