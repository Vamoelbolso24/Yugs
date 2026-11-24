-- Wigglytuff
-- Evolution Summon from "Jigglypuff" (hard once per turn).
-- Cannot be destroyed by battle with a monster whose ATK is equal to or lower than this card's DEF.
-- Once per turn: You can target 1 monster your opponent controls; toss a coin and call it. If you call it
-- right, change that monster to face-down Defense Position.
-- At the start of the Damage Step, if this card attacks a face-down Defense Position monster: Destroy it.
-- PATTERN: "call a coin" = Duel.CallCoin(tp) (true if the player called it right).
-- "At the start of the Damage Step" = EVENT_BATTLE_START (the attacked card is still face-down then).
local s,id=GetID()
function s.initial_effect(c)
	Pokemon.AddEvolutionSummon(c,1900000056)   -- from Jigglypuff

	-- Battle protection: the value function gets the monster it battles (bc)
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_SINGLE)
	e1:SetCode(EFFECT_INDESTRUCTABLE_BATTLE)
	e1:SetValue(function(e,bc) return bc:GetAttack()<=e:GetHandler():GetDefense() end)
	c:RegisterEffect(e1)
	-- Coin toss: flip a monster face-down
	local e2=Effect.CreateEffect(c)
	e2:SetDescription(aux.Stringid(id,0))
	e2:SetCategory(CATEGORY_POSITION+CATEGORY_COIN)
	e2:SetType(EFFECT_TYPE_IGNITION)
	e2:SetRange(LOCATION_MZONE)
	e2:SetProperty(EFFECT_FLAG_CARD_TARGET)
	e2:SetCountLimit(1)
	e2:SetTarget(s.postg)
	e2:SetOperation(s.posop)
	c:RegisterEffect(e2)
	-- Destroy a face-down Defense Position monster it attacks
	local e3=Effect.CreateEffect(c)
	e3:SetCategory(CATEGORY_DESTROY)
	e3:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_TRIGGER_F)
	e3:SetCode(EVENT_BATTLE_START)
	e3:SetCondition(function(e)
		local bc=Duel.GetAttackTarget()
		return Duel.GetAttacker()==e:GetHandler() and bc and bc:IsFacedown() and bc:IsDefensePos()
	end)
	e3:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return true end
		Duel.SetOperationInfo(0,CATEGORY_DESTROY,Duel.GetAttackTarget(),1,0,0)
	end)
	e3:SetOperation(function(e)
		local bc=Duel.GetAttackTarget()
		if bc and bc:IsRelateToBattle() then Duel.Destroy(bc,REASON_EFFECT) end
	end)
	c:RegisterEffect(e3)
end
s.listed_names={1900000056}
s.toss_coin=true   -- tells the engine this card tosses coins

function s.posfilter(c) return c:IsFaceup() and c:IsCanTurnSet() end
function s.postg(e,tp,eg,ep,ev,re,r,rp,chk,chkc)
	if chkc then return chkc:IsLocation(LOCATION_MZONE) and chkc:IsControler(1-tp) and s.posfilter(chkc) end
	if chk==0 then return Duel.IsExistingTarget(s.posfilter,tp,0,LOCATION_MZONE,1,nil) end
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_POSCHANGE)
	local g=Duel.SelectTarget(tp,s.posfilter,tp,0,LOCATION_MZONE,1,1,nil)
	Duel.SetOperationInfo(0,CATEGORY_POSITION,g,1,0,0)
	Duel.SetOperationInfo(0,CATEGORY_COIN,nil,0,tp,1)
end
function s.posop(e,tp,eg,ep,ev,re,r,rp)
	local tc=Duel.GetFirstTarget()
	if not (tc and tc:IsRelateToEffect(e)) then return end
	if Duel.CallCoin(tp) and tc:IsFaceup() then
		Duel.ChangePosition(tc,POS_FACEDOWN_DEFENSE)
	end
end
