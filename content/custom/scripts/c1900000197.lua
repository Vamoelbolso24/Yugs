-- Tauros
-- You can Tribute Summon this card by Tributing 1 Beast Pokemon monster.
-- When this card is Normal Summoned: Halve the ATK of all monsters your opponent controls.
-- During the End Phase, if your opponent drew a card(s) this turn (except during the Draw Phase): You can target 1
-- Pokemon monster in your GY or banishment; add it to your hand.
-- If your opponent drew a card(s) (except during the Draw Phase) during the previous turn, this turn this card gains:
-- * If this card battles a Defense Position monster, inflict double piercing battle damage to your opponent.
local s,id=GetID()
function s.initial_effect(c)
	Pokemon.EnableDrawTracker()
	-- Tribute Summon with only 1 Beast Pokemon (Prompt 1)
	aux.AddNormalSummonProcedure(c,true,true,1,1,SUMMON_TYPE_TRIBUTE,aux.Stringid(id,0),
		function(tc) return tc:IsSetCard(SET_POKEMON) and tc:IsRace(RACE_BEAST) end)
	-- Halve opponent's ATK (mandatory)
	local e1=Effect.CreateEffect(c)
	e1:SetCategory(CATEGORY_ATKCHANGE)
	e1:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_TRIGGER_F)
	e1:SetCode(EVENT_SUMMON_SUCCESS)
	e1:SetOperation(function(e,tp)
		for tc in Duel.GetMatchingGroup(Card.IsFaceup,tp,0,LOCATION_MZONE,nil):Iter() do
			local ef=Effect.CreateEffect(e:GetHandler())
			ef:SetType(EFFECT_TYPE_SINGLE)
			ef:SetCode(EFFECT_SET_ATTACK_FINAL)
			ef:SetValue(math.ceil(tc:GetAttack()/2))
			ef:SetReset(RESET_EVENT|RESETS_STANDARD)
			tc:RegisterEffect(ef)
		end
	end)
	c:RegisterEffect(e1)
	-- End Phase: recover a Pokemon
	local e2=Effect.CreateEffect(c)
	e2:SetDescription(aux.Stringid(id,1))
	e2:SetCategory(CATEGORY_TOHAND)
	e2:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_TRIGGER_O)
	e2:SetCode(EVENT_PHASE+PHASE_END)
	e2:SetRange(LOCATION_MZONE)
	e2:SetProperty(EFFECT_FLAG_CARD_TARGET)
	e2:SetCountLimit(1)
	e2:SetCondition(function(e,tp) return Pokemon.DrewOutsideDrawPhase(1-tp,0) end)
	e2:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk,chkc)
		if chkc then return chkc:IsLocation(LOCATION_GRAVE|LOCATION_REMOVED) and chkc:IsControler(tp) and s.thfilter(chkc) end
		if chk==0 then return Duel.IsExistingTarget(s.thfilter,tp,LOCATION_GRAVE|LOCATION_REMOVED,0,1,nil) end
		Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_ATOHAND)
		local g=Duel.SelectTarget(tp,s.thfilter,tp,LOCATION_GRAVE|LOCATION_REMOVED,0,1,1,nil)
		Duel.SetOperationInfo(0,CATEGORY_TOHAND,g,1,0,0)
	end)
	e2:SetOperation(function(e,tp)
		local tc=Duel.GetFirstTarget()
		if tc and tc:IsRelateToEffect(e) then Duel.SendtoHand(tc,nil,REASON_EFFECT) Duel.ConfirmCards(1-tp,tc) end
	end)
	c:RegisterEffect(e2)
	-- Double piercing if they drew outside the Draw Phase last turn
	local stampede=function(e) return Pokemon.DrewOutsideDrawPhase(1-e:GetHandlerPlayer(),1) end
	local e3=Effect.CreateEffect(c)
	e3:SetType(EFFECT_TYPE_SINGLE)
	e3:SetCode(EFFECT_PIERCE)
	e3:SetCondition(stampede)
	c:RegisterEffect(e3)
	local e4=Effect.CreateEffect(c)
	e4:SetType(EFFECT_TYPE_SINGLE)
	e4:SetCode(EFFECT_CHANGE_BATTLE_DAMAGE)
	e4:SetCondition(function(e)
		local bc=e:GetHandler():GetBattleTarget()
		return stampede(e) and bc and bc:IsDefensePos()
	end)
	e4:SetValue(aux.ChangeBattleDamage(1,DOUBLE_DAMAGE))
	c:RegisterEffect(e4)
end
function s.thfilter(c) return c:IsSetCard(SET_POKEMON) and c:IsMonster() and (c:IsLocation(LOCATION_GRAVE) or c:IsFaceup()) and c:IsAbleToHand() end
