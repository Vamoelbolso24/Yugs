-- Ivysaur
-- Evolution Summon from "Bulbasaur".
-- During each of your Standby Phases: Your opponent loses 500 LP.
-- Once per turn: target 1 opponent's monster; toss a coin and call it; if right, change it to face-down Defense.
local s,id=GetID()
function s.initial_effect(c)
	-- EVOLUTION SUMMON: the whole mechanic is this one line (see custom_utility.lua).
	Pokemon.AddEvolutionSummon(c,1900000002)   -- 1900000002 = Bulbasaur

	-- Standby Phase drain. PATTERN: "During each of your Standby Phases" = a mandatory trigger (TRIGGER_F)
	-- on EVENT_PHASE+PHASE_STANDBY, with a condition that it's your turn.
	local e1=Effect.CreateEffect(c)
	e1:SetDescription(aux.Stringid(id,0))      -- Prompt 1
	e1:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_TRIGGER_F)
	e1:SetCode(EVENT_PHASE+PHASE_STANDBY)
	e1:SetRange(LOCATION_MZONE)
	e1:SetCountLimit(1)
	e1:SetCondition(function(e,tp) return Duel.IsTurnPlayer(tp) end)
	e1:SetOperation(s.drainop)
	c:RegisterEffect(e1)

	-- Coin toss flip. PATTERN: "Once per turn: You can target ..." = IGNITION + CARD_TARGET + SetCountLimit(1).
	local e2=Effect.CreateEffect(c)
	e2:SetDescription(aux.Stringid(id,1))      -- Prompt 2
	e2:SetCategory(CATEGORY_POSITION+CATEGORY_COIN)
	e2:SetType(EFFECT_TYPE_IGNITION)
	e2:SetRange(LOCATION_MZONE)
	e2:SetProperty(EFFECT_FLAG_CARD_TARGET)
	e2:SetCountLimit(1)
	e2:SetTarget(s.postg)
	e2:SetOperation(s.posop)
	c:RegisterEffect(e2)
end
s.listed_names={1900000002}

-- "loses LP" is not damage: it can't be prevented by damage-stopping cards. It is done with SetLP.
function s.drainop(e,tp,eg,ep,ev,re,r,rp)
	Duel.SetLP(1-tp,math.max(0,Duel.GetLP(1-tp)-500))
end

-- A monster that can be flipped face-down: face-up and allowed to be Set.
function s.posfilter(c)
	return c:IsFaceup() and c:IsCanTurnSet()
end
function s.postg(e,tp,eg,ep,ev,re,r,rp,chk,chkc)
	if chkc then return chkc:IsLocation(LOCATION_MZONE) and chkc:IsControler(1-tp) and s.posfilter(chkc) end
	if chk==0 then return Duel.IsExistingTarget(s.posfilter,tp,0,LOCATION_MZONE,1,nil) end
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_POSCHANGE)
	local g=Duel.SelectTarget(tp,s.posfilter,tp,0,LOCATION_MZONE,1,1,nil)
	Duel.SetOperationInfo(0,CATEGORY_COIN,nil,0,tp,1)
	Duel.SetOperationInfo(0,CATEGORY_POSITION,g,1,0,0)
end
function s.posop(e,tp,eg,ep,ev,re,r,rp)
	local tc=Duel.GetFirstTarget()
	-- Duel.CallCoin(tp): the player calls heads or tails, the coin is tossed, returns true if they called it right.
	if Duel.CallCoin(tp) and tc and tc:IsRelateToEffect(e) and tc:IsFaceup() then
		Duel.ChangePosition(tc,POS_FACEDOWN_DEFENSE)
	end
end
