-- Hydro Cannon (Normal Spell)
-- Target 1 "Blastoise" you control; double its ATK until the end of your opponent's next turn, but it
-- cannot attack directly this turn.
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
s.listed_names={1900000010}   -- Blastoise

function s.bfilter(c)
	return c:IsFaceup() and c:IsCode(1900000010)
end
function s.target(e,tp,eg,ep,ev,re,r,rp,chk,chkc)
	if chkc then return chkc:IsLocation(LOCATION_MZONE) and chkc:IsControler(tp) and s.bfilter(chkc) end
	if chk==0 then return Duel.IsExistingTarget(s.bfilter,tp,LOCATION_MZONE,0,1,nil) end
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_FACEUP)
	Duel.SelectTarget(tp,s.bfilter,tp,LOCATION_MZONE,0,1,1,nil)
end
function s.activate(e,tp,eg,ep,ev,re,r,rp)
	local tc=Duel.GetFirstTarget()
	if not (tc and tc:IsRelateToEffect(e) and tc:IsFaceup()) then return end
	-- Double ATK. PATTERN: "double its ATK" = SET_ATTACK_FINAL to twice its current ATK (like Limiter Removal).
	local e1=Effect.CreateEffect(e:GetHandler())
	e1:SetType(EFFECT_TYPE_SINGLE)
	e1:SetCode(EFFECT_SET_ATTACK_FINAL)
	e1:SetValue(tc:GetAttack()*2)
	-- PATTERN: "until the end of your opponent's next turn" = reset at the End Phase of the opponent's turn.
	e1:SetReset(RESETS_STANDARD_PHASE_END|RESET_OPPO_TURN)
	tc:RegisterEffect(e1)
	-- Can't attack directly this turn.
	local e2=Effect.CreateEffect(e:GetHandler())
	e2:SetType(EFFECT_TYPE_SINGLE)
	e2:SetCode(EFFECT_CANNOT_DIRECT_ATTACK)
	e2:SetReset(RESETS_STANDARD_PHASE_END)
	tc:RegisterEffect(e2)
end
