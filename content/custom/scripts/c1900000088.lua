-- Gym Leader - Brock (Continuous Spell)
-- You can only control 1 "Gym Leader" card.
-- Rock monsters you control gain 500 DEF, also if they are targeted for an attack while in Defense Position,
-- the battle damage your opponent takes from that battle is doubled.
-- During your opponent's Standby Phase: Target 1 monster they control; change it to Attack Position, also this
-- turn it cannot change its battle position and it must attack a Defense Position Rock Pokemon monster you
-- control, if able.
local s,id=GetID()
function s.initial_effect(c)
	Pokemon.AddGymLeader(c)
	-- +500 DEF
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_FIELD)
	e1:SetCode(EFFECT_UPDATE_DEFENSE)
	e1:SetRange(LOCATION_SZONE)
	e1:SetTargetRange(LOCATION_MZONE,0)
	e1:SetTarget(function(e,tc) return tc:IsRace(RACE_ROCK) end)
	e1:SetValue(500)
	c:RegisterEffect(e1)
	-- Double the damage the attacker's controller takes when attacking a Defense Position Rock
	local e2=Effect.CreateEffect(c)
	e2:SetType(EFFECT_TYPE_FIELD)
	e2:SetCode(EFFECT_CHANGE_BATTLE_DAMAGE)
	e2:SetRange(LOCATION_SZONE)
	e2:SetTargetRange(LOCATION_MZONE,0)
	e2:SetTarget(function(e,tc) return tc:IsRace(RACE_ROCK) and tc:IsDefensePos() and Duel.GetAttackTarget()==tc end)
	e2:SetValue(function(e,damp) return damp==1-e:GetHandlerPlayer() and DOUBLE_DAMAGE or -1 end)
	c:RegisterEffect(e2)
	-- Opponent's Standby Phase (mandatory)
	local e3=Effect.CreateEffect(c)
	e3:SetCategory(CATEGORY_POSITION)
	e3:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_TRIGGER_F)
	e3:SetCode(EVENT_PHASE+PHASE_STANDBY)
	e3:SetRange(LOCATION_SZONE)
	e3:SetProperty(EFFECT_FLAG_CARD_TARGET)
	e3:SetCountLimit(1)
	e3:SetCondition(function(e,tp) return Duel.IsTurnPlayer(1-tp) end)
	e3:SetTarget(s.target)
	e3:SetOperation(s.operation)
	c:RegisterEffect(e3)
end
function s.target(e,tp,eg,ep,ev,re,r,rp,chk,chkc)
	if chkc then return chkc:IsLocation(LOCATION_MZONE) and chkc:IsControler(1-tp) end
	if chk==0 then return Duel.IsExistingTarget(nil,tp,0,LOCATION_MZONE,1,nil) end
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_TARGET)
	local g=Duel.SelectTarget(tp,nil,tp,0,LOCATION_MZONE,1,1,nil)
	Duel.SetOperationInfo(0,CATEGORY_POSITION,g,1,0,0)
end
-- a Defense Position Rock Pokemon on the Gym Leader's side
function s.rockdef(c,tp) return c:IsFaceup() and c:IsControler(tp) and c:IsRace(RACE_ROCK) and c:IsSetCard(SET_POKEMON) and c:IsDefensePos() end
function s.operation(e,tp)
	local c=e:GetHandler()
	local tc=Duel.GetFirstTarget()
	if not (c:IsRelateToEffect(e) and tc and tc:IsRelateToEffect(e)) then return end
	if not tc:IsAttackPos() then Duel.ChangePosition(tc,POS_FACEUP_ATTACK) end
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_SINGLE)
	e1:SetCode(EFFECT_CANNOT_CHANGE_POSITION)
	e1:SetReset(RESETS_STANDARD_PHASE_END)
	tc:RegisterEffect(e1)
	-- "must attack ... if able": only forced while such a Rock exists
	local able=function() return Duel.IsExistingMatchingCard(s.rockdef,tp,LOCATION_MZONE,0,1,nil,tp) end
	local e2=Effect.CreateEffect(c)
	e2:SetType(EFFECT_TYPE_SINGLE)
	e2:SetCode(EFFECT_MUST_ATTACK)
	e2:SetCondition(able)
	e2:SetReset(RESETS_STANDARD_PHASE_END)
	tc:RegisterEffect(e2)
	local e3=e2:Clone()
	e3:SetCode(EFFECT_MUST_ATTACK_MONSTER)
	e3:SetValue(function(e,bc) return s.rockdef(bc,tp) end)
	tc:RegisterEffect(e3)
end
