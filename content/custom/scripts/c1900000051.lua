-- Clefable
-- Evolution Summon from "Clefairy" (hard once per turn).
-- Your opponent cannot target this card with card effects. When this card attacks, during damage
-- calculation your opponent's monster's ATK/DEF become their original ATK/DEF.
-- Once per turn, during your turn: excavate the top card of your Deck; if it's a Normal Spell, apply
-- its effects, then shuffle it into the Deck. Otherwise, place it on the bottom.
-- Once per turn, during your opponent's turn (Quick Effect): excavate the top card of your Deck; if it's
-- a Normal Trap and this is a moment it could be activated, apply its effects, then shuffle it into the Deck.
-- Otherwise, place it on the bottom. You can only activate each effect of "Clefable" once per turn.
-- HOW THE TRAP TIMING WORKS: Traps like Mirror Force can only be used when something happens (an attack,
-- a Summon...). When the Quick Effect is activated, it writes down what is happening right now (EVENTS
-- below, checked with Duel.CheckEvent). When it resolves, the Trap is applied only if it waits for one of
-- those moments (or can be used at any time), and it gets that moment's details (which monster attacked...).
local s,id=GetID()
local EVENTS={EVENT_ATTACK_ANNOUNCE,EVENT_BE_BATTLE_TARGET,EVENT_SUMMON_SUCCESS,EVENT_SPSUMMON_SUCCESS,
	EVENT_FLIP_SUMMON_SUCCESS,EVENT_CHAINING}
s.moments={}   -- what was happening for each Chain Link, filled in s.traptg
function s.initial_effect(c)
	Pokemon.AddEvolutionSummon(c,1900000050)   -- from Clefairy

	-- Opponent can't target it
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_SINGLE)
	e1:SetProperty(EFFECT_FLAG_SINGLE_RANGE)
	e1:SetRange(LOCATION_MZONE)
	e1:SetCode(EFFECT_CANNOT_BE_EFFECT_TARGET)
	e1:SetValue(aux.tgoval)
	c:RegisterEffect(e1)
	-- When it attacks: the attacked monster uses its original ATK/DEF during damage calculation
	local e2=Effect.CreateEffect(c)
	e2:SetType(EFFECT_TYPE_FIELD)
	e2:SetCode(EFFECT_SET_ATTACK_FINAL)
	e2:SetRange(LOCATION_MZONE)
	e2:SetTargetRange(0,LOCATION_MZONE)
	e2:SetCondition(function(e)
		return Duel.GetCurrentPhase()==PHASE_DAMAGE_CAL and Duel.GetAttacker()==e:GetHandler()
			and Duel.GetAttackTarget()~=nil
	end)
	e2:SetTarget(function(e,tc) return tc==Duel.GetAttackTarget() end)
	e2:SetValue(function(e,tc) return tc:GetBaseAttack() end)
	c:RegisterEffect(e2)
	local e3=e2:Clone()
	e3:SetCode(EFFECT_SET_DEFENSE_FINAL)
	e3:SetValue(function(e,tc) return tc:GetBaseDefense() end)
	c:RegisterEffect(e3)
	-- Your turn: excavate for a Normal Spell (Prompt 1)
	local e4=Effect.CreateEffect(c)
	e4:SetDescription(aux.Stringid(id,0))
	e4:SetType(EFFECT_TYPE_IGNITION)
	e4:SetRange(LOCATION_MZONE)
	e4:SetCountLimit(1,{id,1})                 -- hard once per turn, own counter
	e4:SetTarget(s.deckcheck)
	e4:SetOperation(function(e,tp,eg,ep,ev,re,r,rp)
		Pokemon.ExcavateAndApply(e,tp,eg,ep,ev,re,r,rp,Card.IsNormalSpell)
	end)
	c:RegisterEffect(e4)
	-- Opponent's turn: excavate for a Normal Trap (Prompt 2)
	local e5=Effect.CreateEffect(c)
	e5:SetDescription(aux.Stringid(id,1))
	e5:SetType(EFFECT_TYPE_QUICK_O)
	e5:SetCode(EVENT_FREE_CHAIN)
	e5:SetRange(LOCATION_MZONE)
	e5:SetCountLimit(1,{id,2})                 -- hard once per turn, own counter
	e5:SetCondition(function(e,tp) return Duel.IsTurnPlayer(1-tp) end)
	e5:SetTarget(s.traptg)
	e5:SetOperation(s.trapop)
	c:RegisterEffect(e5)
end
s.listed_names={1900000050}

function s.deckcheck(e,tp,eg,ep,ev,re,r,rp,chk)
	if chk==0 then return Duel.GetFieldGroupCount(tp,LOCATION_DECK,0)>0 end
end
-- On activation: remember which special moments are happening right now.
function s.traptg(e,tp,eg,ep,ev,re,r,rp,chk)
	if chk==0 then return Duel.GetFieldGroupCount(tp,LOCATION_DECK,0)>0 end
	local now={}
	for _,code in ipairs(EVENTS) do
		local res,teg,tep,tev,tre,tr,trp=Duel.CheckEvent(code,true)
		if res then now[code]={teg,tep,tev,tre,tr,trp} end
	end
	s.moments[Duel.GetCurrentChain()]=now
end
function s.trapop(e,tp,eg,ep,ev,re,r,rp)
	local now=s.moments[Duel.GetCurrentChain()] or {}
	s.moments[Duel.GetCurrentChain()]=nil
	local chosen=nil
	Pokemon.ExcavateAndApply(e,tp,eg,ep,ev,re,r,rp,Card.IsNormalTrap,function(te)
		if te:GetCode()==EVENT_FREE_CHAIN then return true end
		chosen=now[te:GetCode()]
		return chosen~=nil
	end,function() return chosen end)
end
