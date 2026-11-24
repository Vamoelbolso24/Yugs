-- Curse (Normal Spell)
-- Target 1 Pokemon monster you control; apply the effect for its Type:
-- * Zombie: Pay 3000 LP, then choose 1 face-up Spell/Trap your opponent controls; its effect becomes
--   "During your Standby Phase: Lose 1500 LP."
-- * Any other Type: It gains 500 ATK/DEF.
local s,id=GetID()
function s.initial_effect(c)
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_FREE_CHAIN)
	e1:SetProperty(EFFECT_FLAG_CARD_TARGET)
	e1:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk,chkc)
		if chkc then return chkc:IsLocation(LOCATION_MZONE) and chkc:IsControler(tp) and s.filter(chkc) end
		if chk==0 then return Duel.IsExistingTarget(s.filter,tp,LOCATION_MZONE,0,1,nil) end
		Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_TARGET)
		Duel.SelectTarget(tp,s.filter,tp,LOCATION_MZONE,0,1,1,nil)
	end)
	e1:SetOperation(s.activate)
	c:RegisterEffect(e1)
end
function s.filter(c) return c:IsFaceup() and c:IsSetCard(SET_POKEMON) end
function s.stfilter(c) return c:IsFaceup() and c:IsSpellTrap() end
function s.activate(e,tp)
	local tc=Duel.GetFirstTarget()
	if not (tc and tc:IsRelateToEffect(e) and tc:IsFaceup()) then return end
	if tc:IsRace(RACE_ZOMBIE) then
		-- "Pay 3000 LP, then choose" (happens when it resolves; if you can't pay, nothing happens)
		if not Duel.CheckLPCost(tp,3000) or not Duel.IsExistingMatchingCard(s.stfilter,tp,0,LOCATION_ONFIELD,1,nil) then return end
		Duel.PayLPCost(tp,3000)
		Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_FACEUP)
		local sc=Duel.SelectMatchingCard(tp,s.stfilter,tp,0,LOCATION_ONFIELD,1,1,nil):GetFirst()
		if sc then
			Duel.HintSelection(sc)
			Pokemon.CurseSpellTrap(e:GetHandler(),sc,1500,aux.Stringid(id,0))
		end
	else
		for _,code in ipairs({EFFECT_UPDATE_ATTACK,EFFECT_UPDATE_DEFENSE}) do
			local e1=Effect.CreateEffect(e:GetHandler())
			e1:SetType(EFFECT_TYPE_SINGLE)
			e1:SetCode(code)
			e1:SetValue(500)
			e1:SetReset(RESET_EVENT|RESETS_STANDARD)
			tc:RegisterEffect(e1)
		end
	end
end
