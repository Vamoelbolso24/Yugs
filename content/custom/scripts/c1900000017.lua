-- Butterfree
-- Evolution Summon from "Metapod" (hard once per turn).
-- Once per turn: roll a die; this card gains 1 effect until the end of this turn (3, 4, 5 or 6; 1-2 nothing).
-- If this card attacks, at the end of the Damage Step: You can return it to the hand, and if you do,
-- Special Summon 1 Level 5 or lower Insect Pokemon from your hand, except "Butterfree".
-- PATTERN: "gains an effect until the end of the turn" = create the effect in the operation and
-- register it on the card with SetReset(RESETS_STANDARD_PHASE_END).
local s,id=GetID()
function s.initial_effect(c)
	Pokemon.AddEvolutionSummon(c,1900000016)   -- from Metapod

	-- Roll the die
	local e1=Effect.CreateEffect(c)
	e1:SetDescription(aux.Stringid(id,0))      -- Prompt 1
	e1:SetCategory(CATEGORY_DICE)
	e1:SetType(EFFECT_TYPE_IGNITION)
	e1:SetRange(LOCATION_MZONE)
	e1:SetCountLimit(1)
	e1:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return true end
		Duel.SetOperationInfo(0,CATEGORY_DICE,nil,0,tp,1)
	end)
	e1:SetOperation(s.rollop)
	c:RegisterEffect(e1)

	-- Return to hand and switch, at the end of the Damage Step if this card attacked
	local e2=Effect.CreateEffect(c)
	e2:SetDescription(aux.Stringid(id,5))      -- Prompt 6
	e2:SetCategory(CATEGORY_TOHAND+CATEGORY_SPECIAL_SUMMON)
	e2:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_TRIGGER_O)
	e2:SetCode(EVENT_DAMAGE_STEP_END)
	e2:SetCondition(function(e) local c=e:GetHandler() return Duel.GetAttacker()==c and c:IsOnField() end)
	e2:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return e:GetHandler():IsAbleToHand() end
		Duel.SetOperationInfo(0,CATEGORY_TOHAND,e:GetHandler(),1,0,0)
	end)
	e2:SetOperation(function(e,tp) Pokemon.ReturnAndSwitch(e,tp,e:GetHandler(),5,id) end)
	c:RegisterEffect(e2)
end
s.listed_names={1900000016}

-- What each die result gives: { which Prompt, filter, my locations, opponent's locations, what happens }
local function oppFaceupSettable(c) return c:IsFaceup() and c:IsCanTurnSet() end
local function spellTrapToHand(c) return c:IsSpellTrap() and c:IsAbleToHand() end
local function monsterToHand(c) return c:IsAbleToHand() end
s.results={
	[3]={prompt=1, filter=oppFaceupSettable, mine=0, theirs=LOCATION_MZONE, cat=CATEGORY_POSITION, hint=HINTMSG_POSCHANGE,
		apply=function(e,tc) Duel.ChangePosition(tc,POS_FACEDOWN_DEFENSE) end},
	[4]={prompt=2, filter=aux.TRUE, mine=0, theirs=LOCATION_MZONE, cat=0, hint=HINTMSG_TARGET,
		apply=function(e,tc)
			-- It cannot attack during your opponent's next turn (lasts until the end of that turn).
			local ef=Effect.CreateEffect(e:GetHandler())
			ef:SetType(EFFECT_TYPE_SINGLE)
			ef:SetCode(EFFECT_CANNOT_ATTACK)
			ef:SetProperty(EFFECT_FLAG_CLIENT_HINT)
			ef:SetDescription(aux.Stringid(id,2))
			ef:SetReset(RESETS_STANDARD_PHASE_END|RESET_OPPO_TURN)
			tc:RegisterEffect(ef)
		end},
	[5]={prompt=3, filter=spellTrapToHand, mine=LOCATION_ONFIELD, theirs=LOCATION_ONFIELD, cat=CATEGORY_TOHAND, hint=HINTMSG_RTOHAND,
		apply=function(e,tc) Duel.SendtoHand(tc,nil,REASON_EFFECT) end},
	[6]={prompt=4, filter=monsterToHand, mine=0, theirs=LOCATION_MZONE, cat=CATEGORY_TOHAND, hint=HINTMSG_RTOHAND,
		apply=function(e,tc) Duel.SendtoHand(tc,nil,REASON_EFFECT) end},
}

function s.rollop(e,tp,eg,ep,ev,re,r,rp)
	local c=e:GetHandler()
	local d=Duel.TossDice(tp,1)
	local res=s.results[d]
	if not res or not (c:IsRelateToEffect(e) and c:IsFaceup()) then return end   -- 1-2: nothing
	-- Give this card the matching "Once per turn: You can target ..." effect until the end of the turn.
	local ge=Effect.CreateEffect(c)
	ge:SetDescription(aux.Stringid(id,res.prompt))
	ge:SetCategory(res.cat)
	ge:SetType(EFFECT_TYPE_IGNITION)
	ge:SetRange(LOCATION_MZONE)
	ge:SetProperty(EFFECT_FLAG_CARD_TARGET+EFFECT_FLAG_CLIENT_HINT)
	ge:SetCountLimit(1)
	ge:SetReset(RESETS_STANDARD_PHASE_END)
	ge:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk,chkc)
		local mine,theirs=res.mine,res.theirs
		if chkc then return res.filter(chkc) and chkc:IsOnField()
			and ((chkc:IsControler(tp) and chkc:IsLocation(mine)) or (chkc:IsControler(1-tp) and chkc:IsLocation(theirs))) end
		if chk==0 then return Duel.IsExistingTarget(res.filter,tp,mine,theirs,1,nil) end
		Duel.Hint(HINT_SELECTMSG,tp,res.hint)
		Duel.SelectTarget(tp,res.filter,tp,mine,theirs,1,1,nil)
	end)
	ge:SetOperation(function(e,tp)
		local tc=Duel.GetFirstTarget()
		if tc and tc:IsRelateToEffect(e) then res.apply(e,tc) end
	end)
	c:RegisterEffect(ge)
end
